# Decode the first function map from the actual MCJIT ObjectCache ELF.
# Locate the sret call by its relocation, not by the ordinal of a safepoint.
import pathlib
import struct
import sys

objects = list(pathlib.Path(sys.argv[1]).rglob("*.o"))
assert len(objects) == 1, "one freshly compiled MCJIT module is required"
blob = objects[0].read_bytes()
assert blob[:6] == b'\x7fELF\x02\x01', 'expected ELF64 little endian'
shoff = struct.unpack_from('<Q', blob, 40)[0]
entsize, count, names = struct.unpack_from('<HHH', blob, 58)
sections = [struct.unpack_from('<IIQQQQIIQQ', blob, shoff + i * entsize)
            for i in range(count)]

def data(section):
    return blob[section[4]:section[4] + section[5]]

def string(table, offset):
    return table[offset:table.index(b'\0', offset)].decode()

strings = data(sections[names])
section = next(s for s in sections
               if string(strings, s[0]) == '.cjmetadata.stackmap')
raw = data(section)
pos = 0

def bits(width):
    global pos
    assert pos + width <= len(raw) * 8, 'truncated stack map'
    value = (int.from_bytes(raw[pos // 8:(pos + width + 7) // 8], 'little')
             >> (pos % 8)) & ((1 << width) - 1)
    pos += width
    return value

def varint():
    tag = bits(4)
    return tag if tag <= 11 else bits(8 * (tag - 11))

stack_size, format_type, saved = varint(), varint(), varint()
for _ in range(bin(saved).count('1')):
    varint()
rows = varint()
widths = [varint() for _ in range(6)] if rows else []
padding = varint()
bits(padding)
values = []
for _ in range(rows):
    pc = bits(32)
    indices = [bits(w) for w in widths]
    values.append((pc, indices))

symtab = next(s for s in sections if s[1] == 2)
symstrings = data(sections[symtab[6]])
symbols = [struct.unpack_from('<IBBHQQ', blob, off)
           for off in range(symtab[4], symtab[4] + symtab[5], symtab[9])]
function = next(s for s in symbols if string(symstrings, s[0]) == 'sret_forward')
_, _, _, text_index, start, size = function
code = data(sections[text_index])[start:start + size]
returns = []
for section in sections:
    if section[1] != 4 or section[7] != text_index:  # SHT_RELA for this text
        continue
    for off in range(section[4], section[4] + section[5], section[9]):
        offset, info, addend = struct.unpack_from('<QQq', blob, off)
        symbol = symbols[info >> 32]
        if (string(symstrings, symbol[0]) == 'fill' and
                start <= offset < start + size):
            assert info & 0xffffffff in (2, 4), 'expected PC32/PLT32 call'
            pc = offset + 4 - start
            assert code[pc - 5] == 0xe8, 'relocation must name a direct call'
            returns.append(pc)
assert len(returns) == 1, 'fixture must contain exactly one call to fill'
pc = returns[0]
indices = next((idx for address, idx in values if address == pc), None)
live = indices is not None and bool(indices[4] or indices[5])
print('TARGET sret_live_stack_pointer={} pc={} indices={} rows={} decoded={}'.format(
    live, pc, indices, rows, values), flush=True)
assert live, 'sret return PC must retain a live stack-pointer map'
# The last map is the return poll after the frame has been removed. Its empty
# pointer map is an independent negative control, including on the cut arms.
assert values[-1][1][4:] == [0, 0], 'sret pointer is dead at the return poll'
assert code.startswith(bytes.fromhex('55 48 89 e5')), 'JIT must preserve RBP'
print('TARGET sret_return_pc={} verified=true frame_pointer=rbp'.format(pc))
