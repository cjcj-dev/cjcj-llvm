#!/usr/bin/env python3
"""Bind backend TLAB offsets to the runtime's compiled layout assertions.

Run with --runtime <runtime-repository> before building a joint SDK. --write
regenerates the checked-in header; the default checks it without modifying it.
The runtime build must also succeed: parsing an assertion does not prove it.
"""
import argparse
from pathlib import Path
import re
import sys


def assertion(source, structure, member):
    pattern = (r'static_assert\(offsetof\(' + structure + r',\s*' + member +
               r'\)\s*==\s*(\d+),\s*"compiler [^"]+ ABI"\);')
    values = re.findall(pattern, source)
    if len(values) != 1:
        raise ValueError(f"expected one numeric ABI assertion for {structure}.{member}")
    return int(values[0])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime', required=True, type=Path)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    src = args.runtime / 'runtime/src'
    tlab = (src / 'Heap/z/zThreadLocalAllocBuffer.cpp').read_text()
    tls = (src / 'Mutator/ThreadLocal.h').read_text()
    inline = assertion(tlab, 'AllocBuffer', 'tlab')
    values = {
        'BufferOffset': assertion(tls, 'ThreadLocalData', 'buffer'),
        'TopOffset': inline + assertion(tlab, 'TLAB', 'top'),
        'EndOffset': inline + assertion(tlab, 'TLAB', 'end'),
    }
    header = Path(__file__).resolve().parents[1] / 'include/llvm/CodeGen/CangjieTLABLayout.h'
    text = header.read_text()
    for name, value in values.items():
        pattern = rf'constexpr unsigned {name} = (\d+);'
        found = re.findall(pattern, text)
        if len(found) != 1:
            raise ValueError(f"missing or duplicate compiler constant {name}")
        if args.write:
            text = re.sub(pattern, f'constexpr unsigned {name} = {value};', text)
        elif int(found[0]) != value:
            raise ValueError(f"{name}: compiler={found[0]}, runtime={value}")
    if args.write:
        header.write_text(text)
    print('TLAB_LAYOUT ' + ' '.join(f'{k}={v}' for k, v in values.items()))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError) as error:
        print(f'TLAB_LAYOUT_ERROR: {error}', file=sys.stderr)
        sys.exit(1)
