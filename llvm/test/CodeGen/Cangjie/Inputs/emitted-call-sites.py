import argparse
import hashlib
import json
import re
import struct
import subprocess
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--llc', required=True)
p.add_argument('--objdump', required=True)
p.add_argument('--target', required=True)
p.add_argument('--out', required=True)
p.add_argument('--case')
p.add_argument('--generate-only', action='store_true')
p.add_argument('--object', help='check an existing object without invoking llc')
p.add_argument('--inject-pc-error', action='store_true',
               help='offline checker control: shift a caller PC in memory')
a = p.parse_args()
out = Path(a.out)
out.mkdir(parents=True, exist_ok=True)
sp = 'call token (i64, i32, void ()*, i32, i32, ...) @llvm.experimental.gc.statepoint.p0f_isVoidf(i64 0, i32 0, void ()* elementtype(void ()) @%s, i32 0, i32 0, i32 0, i32 0)'
cases = [
    ('helper_marker', 'call void @CJ_MCC_GetMethodOuterTI()\ncall void @SetDebugLocation()', 1),
    ('marker_only', 'call void @SetDebugLocation()', 0),
    ('markers_adjacent', 'call void @SetDebugLocation()\ncall void @SetDebugLocation()', 0),
    ('direct_indirect', 'call void @callee()\ncall void %fp()', 2),
    ('statepoint', '%s = ' + sp % 'callee', 1),
    ('ffi_statepoint', '%s = ' + sp % 'native', 1),
    ('throw_statepoint', '%s = ' + sp % 'CJ_MCC_ThrowException', 1),
]
def elf_sections(data):
    assert data[:6] == b'\x7fELF\x02\x01', 'not a 64-bit little-endian ELF'
    off = struct.unpack_from('<Q', data, 40)[0]
    size, count, strings = struct.unpack_from('<HHH', data, 58)
    headers = [struct.unpack_from('<IIQQQQIIQQ', data, off + i*size) for i in range(count)]
    sh = headers[strings]
    names = data[sh[4]:sh[4]+sh[5]]
    named = {names[h[0]:].split(b'\0', 1)[0].decode(): i for i, h in enumerate(headers)}
    return headers, named


def section(data, name):
    headers, named = elf_sections(data)
    assert name in named, 'missing section ' + name
    h = headers[named[name]]
    return data[h[4]:h[4]+h[5]]


def function_origin(data, qualification_offset):
    # Resolve the funcdesc's entry and qualification fields through ELF RELA.
    # CJMetadata.cpp and CangjieRuntimeLayout.h specify offsets 32/36/40.
    headers, named = elf_sections(data)
    machine = struct.unpack_from('<H', data, 18)[0]
    assert machine in (62, 183), 'unsupported ELF target'
    symtabs = {}
    functions = []
    mappings = []
    for i, h in enumerate(headers):
        if h[1] != 2:
            continue
        strings = headers[h[6]]
        names = data[strings[4]:strings[4]+strings[5]]
        symbols = []
        for pos in range(h[4], h[4]+h[5], h[9]):
            name, info, other, index, value, size = struct.unpack_from('<IBBHQQ', data, pos)
            label = names[name:].split(b'\0', 1)[0].decode()
            symbols.append((index, value))
            if label.startswith(('$d.', '$x.')) or label in ('$d', '$x'):
                mappings.append((index, value, label[:2]))
            if label == 'test' and info & 15 == 2 and 0 < index < len(headers):
                functions.append((index, value, size))
        symtabs[i] = symbols
    assert len(functions) == 1, 'function symbol association is not unique'
    index, entry, extent = functions[0]
    desc = section(data, '.cjmetadata.methodinfo')
    assert len(desc) == 48, 'fixture must have one ELF funcdesc'
    assert struct.unpack_from('<I', desc, 40)[0] == 0x31514a43, 'missing funcdesc qualification tag'
    assert struct.unpack_from('<I', desc, 4)[0] == extent, 'funcdesc/symbol extent differs'
    fields = {}
    for h in headers:
        if h[1] != 4 or h[7] != named['.cjmetadata.methodinfo']:
            continue
        for pos in range(h[4], h[4]+h[5], h[9]):
            offset, info, addend = struct.unpack_from('<QQq', data, pos)
            if offset not in (32, 36):
                continue
            assert offset not in fields, 'duplicate descriptor relocation'
            assert info & 0xffffffff == (2 if machine == 62 else 261), 'unexpected relative relocation'
            symbol_section, symbol_value = symtabs[h[6]][info >> 32]
            fields[offset] = (symbol_section, symbol_value + addend)
    assert fields.get(32) == (index, entry), 'funcdesc entry does not name test'
    assert fields.get(36) == (named['.cjmetadata.stackmap'], qualification_offset), 'qualification is not associated with test'
    text_name = next(name for name, i in named.items() if i == index)
    return text_name, entry, extent, sorted((value, kind) for section, value, kind in mappings if section == index)

results = []
for name, body, expected in cases:
    if a.case and a.case != name:
        continue
    ir = out / (name + '.ll')
    obj = Path(a.object) if a.object else out / (name + '.o')
    ir.write_text('''define void @test(void ()* %fp) gc "cangjie" {
''' + body + '''
ret void
}
declare void @callee()
declare void @CJ_MCC_GetMethodOuterTI()
declare void @SetDebugLocation()
declare void @CJ_MCC_ThrowException()
declare !CallFrameSizeForCJFFI !1 void @native() "cj2c"
declare void @CJ_MCC_C2NStub()
@native.CJStubGV = external global i8*
declare token @llvm.experimental.gc.statepoint.p0f_isVoidf(i64, i32, void ()*, i32, i32, ...)
!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"emitted_call_sites"}
!1 = !{i64 0}
''')
    if a.generate_only:
        print('GENERATED', str(ir), flush=True)
        continue
    cmd = [a.llc, '--cangjie-pipeline', '-mtriple=' + a.target, '-O2', '-filetype=obj', str(ir), '-o', str(obj)]
    if a.object:
        r = subprocess.CompletedProcess(['existing-object', str(obj)], 0, '', '')
    else:
        r = subprocess.run(cmd, capture_output=True, text=True)
    (out/(name+'.stderr')).write_text(r.stderr)
    row = {'case': name, 'command': r.args, 'execution': 'offline-object' if a.object else 'llc', 'rc': r.returncode, 'expected_callers': expected}
    try:
        assert r.returncode == 0, 'object emission failed: ' + r.stderr
        data = obj.read_bytes()
        row['elf_sha256'] = hashlib.sha256(data).hexdigest()
        metadata = section(data, '.cjmetadata.stackmap')
        offset = metadata.find(b'CJQ1')
        assert offset >= 0, 'missing qualification'
        _, length, transitions, sites = struct.unpack_from('<IIII', metadata, offset)
        assert length == 16 + 8*(transitions+sites), 'invalid format'
        records = [struct.unpack_from('<IHH', metadata, offset+16+8*transitions+8*i) for i in range(sites)]
        text_section, entry, extent, mappings = function_origin(data, offset)
        row['function_origin'] = {'section': text_section, 'entry': entry, 'extent': extent}
        row['sites'] = records
        if a.inject_pc_error:
            assert a.object, 'derived-record control is offline only'
            records = [(pc + (1 if kind == 1 else 0), kind, bits) for pc, kind, bits in records]
            row['derived_sites'] = records
        callers = [pc for pc, kind, bits in records if kind == 1]
        returns = [pc for pc, kind, bits in records if kind == 3]
        d = subprocess.run([a.objdump, '-d', str(obj)], capture_output=True, text=True)
        (out/(name+'.disassembly')).write_text(d.stdout+d.stderr)
        assert d.returncode == 0, 'disassembler failed'
        hardware_returns = set()
        instructions = []
        active_section = None
        for line in d.stdout.splitlines():
            if line.startswith('Disassembly of section '):
                active_section = line[len('Disassembly of section '):].rstrip(':')
            if active_section != text_section:
                continue
            m = re.match(r'\s*([0-9a-f]+):\s*(.*)', line)
            if not m:
                continue  # A symbol heading or section header, not an address row.
            addr = int(m[1], 16)
            if not entry <= addr < entry + extent:
                continue
            # AArch64 ELF mapping symbols distinguish inline data from code.
            preceding = [kind for value, kind in mappings if value <= addr]
            if preceding and preceding[-1] == '$d':
                continue
            machine = struct.unpack_from('<H', data, 18)[0]
            pattern = (r'((?:[0-9a-f]{2}\s+)+)\s*(\S.*)$' if machine == 62
                       else r'([0-9a-f]{8})\s+(\S.*)$')
            instruction = re.fullmatch(pattern, m[2])
            assert instruction, 'unparsed function instruction: ' + line
            size = len(instruction[1].split()) if machine == 62 else 4
            assert 0 < size <= (15 if machine == 62 else 4), 'invalid instruction width'
            assert addr + size <= entry + extent, 'instruction crosses function extent'
            asm = instruction[2]
            assert re.match(r'[a-z][a-z0-9.]*\b', asm), 'unknown function instruction: ' + line
            instructions.append((addr, asm))
            if re.match(r'(callq?|bl|blr)\s', asm):
                hardware_returns.add(addr+size-entry)
        row['hardware_return_pcs'] = sorted(hardware_returns)
        # Print the reached target before every causal assertion, including red.
        print('TARGET_REACHED', name, json.dumps(row), flush=True)
        assert len(callers) == expected, 'caller site count differs from actual call events'
        assert set(callers) <= hardware_returns, 'caller site is not a hardware return PC'
        assert len(returns) == 1, 'return poll site lost or duplicated'
        assert len(set((pc, kind) for pc, kind, bits in records)) == len(records), 'duplicate saved site'
        row['status'] = 'PASS'
    except AssertionError as e:
        row['status'] = 'FAIL'
        row['assertion'] = str(e)
    results.append(row)
    print(row['status'], name, row.get('assertion', ''), flush=True)
    if row['status'] != 'PASS':
        break
(out/'results.json').write_text(json.dumps(results, indent=2)+'\n')
raise SystemExit(any(r['status'] != 'PASS' for r in results))
