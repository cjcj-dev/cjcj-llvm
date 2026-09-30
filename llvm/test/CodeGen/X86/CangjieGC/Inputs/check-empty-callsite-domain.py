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


def decode(symbol):
    _, section, start, size = symbol
    metadata, offset = target(section, start - 4)
    stackmap, offset = target(metadata, offset)
    buf = data(stackmap)[offset:]
    cursor = 0
    def take(width):
        nonlocal cursor
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
    widths = [var() for _ in range(6)] if count else []
    take(var())
    rows = [[take(32)] + [take(width) for width in widths] for _ in range(count)]
    return {"stack": stack, "format": fmt, "rows": rows}

maps = {}
for table in symbols.values():
    for symbol in table:
        name, section, start, size = symbol
        if size and (section, start - 4) in relocations:
            maps[name] = decode(symbol)
if len(sys.argv) > 2 and sys.argv[2] == "--export":
    returns = []
    for table in symbols.values():
        for label, section, pc, size in table:
            if not re.search(r"cj_return_pc[0-9]+$", label):
                continue
            owners = [s for t in symbols.values() for s in t
                      if s[3] and s[1] == section and s[2] <= pc < s[2] + s[3]]
            assert len(owners) == 1, (label, owners)
            owner = owners[0]
            returns.append([owner[0], pc - owner[2]])
    output = {"object_sha256": hashlib.sha256(raw).hexdigest(),
              "maps": maps, "return_pcs": sorted(returns)}
    print(json.dumps(output, sort_keys=True))
    sys.exit(0)

# Every target verdict is printed and evaluated, even when another fails.
# This distinguishes a rejected ordinary site from a lost return PC.
checks = {
    "ORDINARY_EMPTY_REJECTED": "ordinary_empty" in maps and not maps["ordinary_empty"]["rows"],
    "ORDINARY_ROOT_RETAINED": "ordinary_root" in maps and len(maps["ordinary_root"]["rows"]) == 1
        and any(maps["ordinary_root"]["rows"][0][1:3]),
    "EMPTY_RETURN_PC_RETAINED": "return_empty" in maps and len(maps["return_empty"]["rows"]) == 1
        and not any(maps["return_empty"]["rows"][0][1:]),
    "ROOT_RETURN_PC_RETAINED": "return_root" in maps and len(maps["return_root"]["rows"]) == 1
        and bool(maps["return_root"]["rows"][0][1]),
}
print(json.dumps(maps, sort_keys=True))
for name, okay in checks.items():
    print(name + "=" + str(okay), flush=True)
sys.exit(0 if all(checks.values()) else 1)
