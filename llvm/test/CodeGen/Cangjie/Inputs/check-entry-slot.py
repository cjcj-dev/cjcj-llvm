"""Check final linked ELF bytes, not a copy of the runtime descriptor lookup."""
import struct
import sys

with open(sys.argv[1], "rb") as stream:
    data = stream.read()
assert data[:6] == b"\x7fELF\x02\x01", "expected ELF64 little endian"
section_offset = struct.unpack_from("<Q", data, 40)[0]
section_size, section_count = struct.unpack_from("<HH", data, 58)
sections = [struct.unpack_from("<IIQQQQIIQQ", data,
                             section_offset + i * section_size)
            for i in range(section_count)]
symbols = {}
for section in sections:
    if section[1] != 2:  # SHT_SYMTAB
        continue
    strings = sections[section[6]]
    names = data[strings[4]:strings[4] + strings[5]]
    for pos in range(section[4], section[4] + section[5], section[9]):
        name, info, other, index, value, size = struct.unpack_from("<IBBHQQ", data, pos)
        name = names[name:names.index(b"\0", name)].decode()
        if name in ("slot_neighbor", "slot_leaf", "slot_gc_leaf", "slot_plain"):
            symbols[name] = (index, value, size)


def slot(name):
    index, value, _ = symbols[name]
    section = sections[index]
    offset = section[4] + value - section[3] - 4
    assert section[4] <= offset < section[4] + section[5] - 3
    return data[offset:offset + 4]


neighbor = slot("slot_neighbor")
leaf = slot("slot_leaf")
functions = sorted((value, name) for name, (_, value, _) in symbols.items())
checks = [
    ("neighbor_nonzero_slot", neighbor != b"\0" * 4, neighbor.hex()),
    ("leaf_nonzero_slot", leaf != b"\0" * 4, leaf.hex()),
    ("adjacent_managed_functions",
     [name for _, name in functions] == ["slot_neighbor", "slot_leaf", "slot_gc_leaf", "slot_plain"]
     and symbols["slot_neighbor"][0] == symbols["slot_leaf"][0], str(functions)),
]
# Evaluate every target even when another fails, so an early assertion cannot
# hide the leaf-slot result or its nonzero positive control.
for name, passed, observed in checks:
    print("{} {} observed={}".format("PASS" if passed else "FAIL", name, observed))
sys.exit(0 if all(passed for _, passed, _ in checks) else 1)
