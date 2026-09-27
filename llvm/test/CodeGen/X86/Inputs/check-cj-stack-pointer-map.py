# Decode the first function's map directly from llc's ELF output. The fixture
# puts sret_forward first; no assembly-comment decoder is used by this check.
import struct
import sys

blob = open(sys.argv[1], 'rb').read()
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
legacy = '--legacy' in sys.argv
widths = [varint() for _ in range(4 if legacy else 6)] if rows else []
padding = varint()
bits(padding)
values = []
for _ in range(rows):
    pc = bits(32)
    indices = [bits(w) for w in widths]
    values.append((pc, indices))

# Assert the semantic target before any incidental table-size expectation.
live = bool(values) and not legacy and bool(values[0][1][4] or values[0][1][5])
print('TARGET sret_live_stack_pointer={} rows={} widths={} decoded={}'.format(
    live, rows, widths, values), flush=True)
assert live, 'sret return PC must retain a live stack-pointer map'
assert rows == 2, 'fixture has a call return PC and a return poll'
assert values[1][1][4:] == [0, 0], 'sret pointer is dead at the return poll'

symtab = next(s for s in sections if s[1] == 2)
symstrings = data(sections[symtab[6]])
for off in range(symtab[4], symtab[4] + symtab[5], symtab[9]):
    name, info, other, index, value, size = struct.unpack_from('<IBBHQQ', blob, off)
    if string(symstrings, name) == 'sret_forward':
        code = data(sections[index])[value:value + size]
        pc = values[0][0]
        machine = struct.unpack_from('<H', blob, 18)[0]
        if machine == 62:
            assert code[pc - 5] == 0xe8, 'map must name the PC after the sret call'
        elif machine == 183:
            call = int.from_bytes(code[pc - 4:pc], 'little')
            assert call >> 26 == 0x25, 'map must name the PC after the sret call'
        else:
            raise AssertionError('unsupported fixture architecture')
        print('TARGET sret_return_pc={} verified=true'.format(pc))
        break
else:
    raise AssertionError('missing sret_forward symbol')
