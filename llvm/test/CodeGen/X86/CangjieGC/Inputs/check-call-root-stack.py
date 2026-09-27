# Decode the product's ELF relocations and compressed Cangjie stackmap.
# Layout: StackMaps.cpp, DataEncoder::emitPrologueAndStackMapItemHeader,
# emitStackMapItem, writeRegRefAndSlotRef. No compiler log is used as a map.
import hashlib
import json
import re
import struct
import sys
from pathlib import Path

raw = Path(sys.argv[1]).read_bytes()
assert raw[:6] == b"\x7fELF\x02\x01", "expected ELF64 little endian"
header = struct.unpack_from("<HHIQQQIHHHHHH", raw, 16)
assert header[0] == 1, "expected relocatable object"
sections = [struct.unpack_from("<IIQQQQIIQQ", raw, header[5] + i * header[10])
            for i in range(header[11])]


def data(index):
    section = sections[index]
    return raw[section[4]:section[4] + section[5]]


def string(buf, offset):
    return buf[offset:buf.index(b"\0", offset)].decode()


symbols = {}
for index, section in enumerate(sections):
    if section[1] != 2:
        continue
    table = []
    for offset in range(0, section[5], section[9]):
        name, info, other, sec, value, size = struct.unpack_from(
            "<IBBHQQ", data(index), offset)
        table.append((string(data(section[6]), name), sec, value, size))
    symbols[index] = table

relocations = {}
for index, section in enumerate(sections):
    if section[1] != 4:
        continue
    for offset in range(0, section[5], section[9]):
        pos, info, addend = struct.unpack_from("<QQq", data(index), offset)
        relocations[section[7], pos] = (symbols[section[6]][info >> 32], addend)


def target(section, pos):
    symbol, addend = relocations[section, pos]
    return symbol[1], symbol[2] + addend


name = sys.argv[2] if len(sys.argv) > 2 else "call_root_stack"
symbol = next(s for table in symbols.values() for s in table if s[0] == name)
_, section, start, size = symbol
metadata, offset = target(section, start - 4)
stackmap, offset = target(metadata, offset)
buf = data(stackmap)[offset:]
cursor = 0


def take(width):
    global cursor
    assert cursor + width <= len(buf) * 8, "truncated stackmap"
    begin, end = cursor // 8, (cursor + width + 7) // 8
    value = (int.from_bytes(buf[begin:end], "little") >> (cursor % 8)) & ((1 << width) - 1)
    cursor += width
    return value


def var():
    prefix = take(4)
    return prefix if prefix <= 11 else take((prefix - 11) * 8)


stack, fmt, saved = var(), var(), var()
for bit in range(32):
    if saved & (1 << bit):
        var()
count = var()
assert count > 0, "no product stackmap rows"
# Tests use the default stack-grow format (six row columns).
widths = [var() for _ in range(6)]
take(var())
rows = [[take(32)] + [take(width) for width in widths] for _ in range(count)]
reg_count, reg_width = var(), var()
registers = [take(reg_width) for _ in range(reg_count)]
assert fmt == 0, "small fixture must use the bitmap slot format"
slot_count, offset_width, slot_width = var(), var(), var()
slots = [(take(offset_width), take(slot_width)) for _ in range(slot_count)]
line_count, line_width = var(), var()
for _ in range(line_count):
    take(line_width)
derived_count = var()
derived = [(take(widths[0]), take(widths[1])) for _ in range(derived_count)]


def reg_mask(index):
    return registers[index - 1] if index else 0


def slot_mask(index):
    return slots[index - 1][1] if index else 0

call_returns = []
if name == "indirect_root_stack":
    instructions = []
    for line in Path(sys.argv[3]).read_text().splitlines():
        match = re.match(r"\s*([0-9a-f]+):\s+(.*)", line)
        if match:
            instructions.append((int(match[1], 16), match[2]))
    for index, (pc, instruction) in enumerate(instructions):
        if re.match(r"(?:callq?\s+\*|blr\s)", instruction):
            call_returns.append(instructions[index + 1][0] - start)
else:
    for (sec, pos), (callee, addend) in relocations.items():
        if sec == section and start <= pos < start + size and callee[0] == "checkpoint":
            call_returns.append(pos + 4 - start)
calls = []
for pc in call_returns:
    matches = [row for row in rows if row[0] == pc]
    assert len(matches) == 1, "call return must have exactly one product map"
    row = matches[0]
    mask = reg_mask(row[1])
    stack_mask = slot_mask(row[2])
    base_count = bin(mask).count("1") + bin(stack_mask).count("1")
    derived_masks = []
    if row[4]:
        begin = row[4] - 1
        pairs = derived[begin:begin + base_count]
        assert len(pairs) == base_count, "missing derived-root records"
        derived_masks = [reg_mask(pair[0]) for pair in pairs]
    calls.append({"return_offset": pc, "register_mask": mask,
                  "stack_mask": stack_mask, "derived_register_masks": derived_masks})
assert calls, "fixture did not emit a tested call"
print(json.dumps({"sha256": hashlib.sha256(raw).hexdigest(), "function": name,
                  "stack_size": stack, "calls": calls}, sort_keys=True))
# Emit the target assertion verdict before failing so an earlier assertion
# cannot be mistaken for this invariant's negative control.
expect_root = name != "no_root_stack"
okay = all(call["register_mask"] == 0 and bool(call["stack_mask"]) == expect_root
           and not any(call["derived_register_masks"]) for call in calls)
print("CALL_ROOTS_IN_FRAME_STACK=" + str(okay), flush=True)
sys.exit(0 if okay else 1)
