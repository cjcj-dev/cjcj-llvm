# Decode the product's ELF relocations and compressed Cangjie stackmap.
# Layout: StackMaps.cpp, DataEncoder::emitPrologueAndStackMapItemHeader,
# emitStackMapItem, writeRegRefAndSlotRef. No compiler log is used as a map.
import hashlib
import json
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


name = "call_root_stack"
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
calls = []
for (sec, pos), (callee, addend) in relocations.items():
    if sec == section and start <= pos < start + size and callee[0] == "checkpoint":
        pc = pos + 4 - start
        matches = [row for row in rows if row[0] == pc]
        assert len(matches) == 1, "call return must have exactly one product map"
        row = matches[0]
        mask = registers[row[1] - 1] if row[1] else 0
        calls.append({"return_offset": pc, "register_mask": mask, "slot_index": row[2]})
assert calls, "fixture did not emit checkpoint call"
print(json.dumps({"sha256": hashlib.sha256(raw).hexdigest(), "function": name,
                  "stack_size": stack, "calls": calls}, sort_keys=True))
# Emit the target assertion verdict before failing so an earlier assertion
# cannot be mistaken for this invariant's negative control.
okay = all(call["register_mask"] == 0 and call["slot_index"] != 0 for call in calls)
print("CALL_ROOTS_IN_FRAME_STACK=" + str(okay), flush=True)
sys.exit(0 if okay else 1)
