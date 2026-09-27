# Read the first function's actual compressed register table from llc's ELF.
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
widths = [varint() for _ in range(6)] if rows else []
padding = varint()
bits(padding)
values = []
for _ in range(rows):
    pc = bits(32)
    indices = [bits(w) for w in widths]
    values.append((pc, indices))

reg_count, reg_width = varint(), varint()
registers = [bits(reg_width) for _ in range(reg_count)]
expected = int(sys.argv[2], 0)
actual = registers[values[0][1][0] - 1] if values and values[0][1][0] else 0
print('TARGET register_bitmap expected={:#x} actual={:#x} width={} rows={}'.format(
    expected, actual, reg_width, values), flush=True)
assert actual == expected, 'safepoint register bitmap must retain every root bit'
expected_derived = int(sys.argv[3], 0) if len(sys.argv) > 3 else 0
if expected_derived:
    slots, base_width, slot_width = varint(), varint(), varint()
    assert slots == 0, 'this fixture has only register roots'
    lines, line_width = varint(), varint()
    for _ in range(lines):
        bits(line_width)
    derived_count = varint()
    derived = [(bits(widths[0]), bits(widths[1])) for _ in range(derived_count)]
    index = values[0][1][3]
    reg_index = derived[index - 1][0] if index else 0
    actual_derived = registers[reg_index - 1] if reg_index else 0
    print('TARGET derived_bitmap expected={:#x} actual={:#x}'.format(
        expected_derived, actual_derived), flush=True)
    assert actual_derived == expected_derived, 'derived register bitmap must retain every root bit'
assert reg_width == max(1, expected.bit_length(), expected_derived.bit_length()), \
    'register width must include the highest root'

