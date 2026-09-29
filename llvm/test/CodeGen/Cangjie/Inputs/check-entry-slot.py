"""Check final linked ELF bytes, not a copy of the runtime descriptor lookup."""
import re
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


def at(address, size):
    for section in sections:
        if section[1] != 8 and section[3] <= address and address + size <= section[3] + section[5]:
            offset = section[4] + address - section[3]
            return data[offset:offset + size]
    return None


def descriptor(name):
    start = symbols[name][1]
    offset = struct.unpack("<i", slot(name))[0]
    address = start - 4 + offset
    raw = at(address, 32) if offset else None
    if raw is None:
        return None
    map_offset, code_size = struct.unpack_from("<iI", raw)
    flags = struct.unpack_from("<I", raw, 28)[0]
    head = address + map_offset if map_offset else None
    return code_size, flags, head


def frame_size(head):
    raw = at(head, 1) if head is not None else None
    if raw is None:
        return None
    tag = raw[0] & 15
    if tag < 12:
        return tag
    width = (tag - 11) * 8
    raw = at(head, (4 + width + 7) // 8)
    if raw is None:
        return None
    return (int.from_bytes(raw, "little") >> 4) & ((1 << width) - 1)


# The assembly comment is emitted from the product's encoded FnInfo. Compare
# its frame size with the bytes reached through the linked descriptor.
with open(sys.argv[2]) as stream:
    assembly = stream.read()
expected_frames = dict((name, int(size)) for name, size in re.findall(
    r"\.Lstack_map\.(slot_\w+):\s*(?:#|//)StackSize: (\d+)", assembly))

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
for name, poll in [("slot_neighbor", 1), ("slot_leaf", 1), ("slot_gc_leaf", 0)]:
    desc = descriptor(name)
    # Do not stop at descriptor presence: every target invariant is evaluated.
    size_ok = desc is not None and desc[0] == symbols[name][2]
    poll_ok = desc is not None and desc[1] == poll
    observed_frame = frame_size(desc[2]) if desc is not None and size_ok else None
    expected_frame = expected_frames.get(name)
    map_ok = (observed_frame is not None and expected_frame is not None
              and observed_frame == expected_frame)
    checks += [
        (name + "_descriptor_code_size", size_ok, str(desc)),
        (name + "_return_poll", poll_ok, str(desc)),
        (name + "_stackmap_frame", map_ok,
         "frame={} expected={}".format(observed_frame, expected_frame)),
    ]
# Evaluate every target even when another fails, so an early assertion cannot
# hide the leaf-slot result or its nonzero positive control.
for name, passed, observed in checks:
    print("{} {} observed={}".format("PASS" if passed else "FAIL", name, observed))
sys.exit(0 if all(passed for _, passed, _ in checks) else 1)
