#!/usr/bin/env python3
"""Check the *linked* MachO PC/FuncDesc relocations, not assembly spelling."""
import argparse
import json
import struct
from pathlib import Path


def inspect(path):
    data = Path(path).read_bytes()
    magic, = struct.unpack_from('<I', data)
    if magic != 0xfeedfacf:
        raise ValueError('expected a little-endian 64-bit MachO image')
    ncmds, = struct.unpack_from('<I', data, 16)
    offset = 32
    sections = []
    symtab = None
    for _ in range(ncmds):
        cmd, size = struct.unpack_from('<II', data, offset)
        if cmd == 0x19:
            nsects, = struct.unpack_from('<I', data, offset + 64)
            for index in range(nsects):
                pos = offset + 72 + index * 80
                name, segment, address, length, fileoff, align = struct.unpack_from('<16s16sQQII', data, pos)
                sections.append((name.rstrip(b'\0').decode(), segment.rstrip(b'\0').decode(), address, length, fileoff))
        elif cmd == 2:
            symtab = struct.unpack_from('<IIII', data, offset + 8)
        offset += size
    if symtab is None:
        raise ValueError('no symbol table in validation image')
    symoff, count, stroff, strsize = symtab
    strings = data[stroff:stroff + strsize]
    symbols = {}
    for index in range(count):
        nameoff, typ, sect, desc, value = struct.unpack_from('<IBBHQ', data, symoff + 16 * index)
        if typ & 0xe0 or typ & 0xe != 0xe:
            continue
        name = strings[nameoff:strings.index(b'\0', nameoff)].decode()
        symbols[name] = value
    records = []
    for name, segment, address, length, fileoff in sections:
        if (segment, name) == ('__CJ_METADATA', '__cjfuncmap'):
            if length % 16 or address % 8:
                raise ValueError('malformed PC/descriptor records')
            records.extend(struct.iter_unpack('<QQ', data[fileoff:fileoff + length]))
    return symbols, records


def check(path, stripped=False):
    symbols, records = inspect(path)
    eligible = {'map_first': 'funcmap_one', 'map_unused': 'funcmap_one',
                'map_init': 'funcmap_one', 'map_second': 'funcmap_two'}
    expected = {}
    errors = []
    for name, package in eligible.items():
        if '_' + name not in symbols:
            continue
        desc = '.Lmethod_desc.' + package + '._' + name
        if desc not in symbols:
            errors.append('missing descriptor symbol: ' + desc)
        else:
            expected[symbols['_' + name]] = symbols[desc]
    actual = dict(records)
    if len(actual) != len(records):
        errors.append('duplicate startPC')
    if actual != expected:
        errors.append('startPC/FuncDesc pairs differ from linked function/descriptor symbols')
    if not expected:
        errors.append('fixture has no surviving managed functions')
    if stripped and '_map_unused' in symbols:
        errors.append('unreferenced function retained by map')
    for name in ('map_leaf', 'map_plain'):
        if symbols.get('_' + name) in actual:
            errors.append('unmanaged or leaf function included: ' + name)
    result = {'image': str(path), 'records': records, 'expected': sorted(expected.items()),
              'errors': errors, 'target_executed': True, 'pass': not errors}
    print('FUNC_MAP_TARGET ' + json.dumps(result), flush=True)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('image')
    parser.add_argument('--dead-strip', action='store_true')
    args = parser.parse_args()
    raise SystemExit(0 if check(args.image, args.dead_strip)['pass'] else 1)
