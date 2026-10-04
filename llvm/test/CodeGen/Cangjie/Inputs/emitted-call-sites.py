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
def section(data, name):
    # Real ELF64 little endian object produced by llc, not a model of lowering.
    assert data[:6] == b'\x7fELF\x02\x01', 'not a 64-bit little-endian ELF'
    off = struct.unpack_from('<Q', data, 40)[0]
    size, count, strings = struct.unpack_from('<HHH', data, 58)
    headers = [struct.unpack_from('<IIQQQQIIQQ', data, off + i*size) for i in range(count)]
    sh = headers[strings]
    names = data[sh[4]:sh[4]+sh[5]]
    for h in headers:
        n = names[h[0]:].split(b'\0', 1)[0].decode()
        if n == name:
            return data[h[4]:h[4]+h[5]]
    raise AssertionError('missing section ' + name)

results = []
for name, body, expected in cases:
    ir = out / (name + '.ll')
    obj = out / (name + '.o')
    ir.write_text('''define void @test(void ()* %fp) gc "cangjie" {
''' + body + '''
ret void
}
declare void @callee()
declare void @CJ_MCC_GetMethodOuterTI()
declare void @SetDebugLocation()
declare void @CJ_MCC_ThrowException()
declare void @native() "cj2c" !CallFrameSizeForCJFFI !1
declare void @CJ_MCC_C2NStub()
@native.CJStubGV = external global i8*
declare token @llvm.experimental.gc.statepoint.p0f_isVoidf(i64, i32, void ()*, i32, i32, ...)
!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"emitted_call_sites"}
!1 = !{i64 0}
''')
    cmd = [a.llc, '--cangjie-pipeline', '-mtriple=' + a.target, '-O2', '-filetype=obj', str(ir), '-o', str(obj)]
    r = subprocess.run(cmd, capture_output=True, text=True)
    (out/(name+'.stderr')).write_text(r.stderr)
    row = {'case': name, 'command': cmd, 'rc': r.returncode, 'expected_callers': expected}
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
        row['sites'] = records
        callers = [pc for pc, kind, bits in records if kind == 1]
        returns = [pc for pc, kind, bits in records if kind == 3]
        d = subprocess.run([a.objdump, '-d', str(obj)], capture_output=True, text=True)
        (out/(name+'.disassembly')).write_text(d.stdout+d.stderr)
        assert d.returncode == 0, 'disassembler failed'
        hardware_returns = set()
        instructions = []
        for line in d.stdout.splitlines():
            m = re.match(r'\s*([0-9a-f]+):\s+((?:[0-9a-f]{2}\s+)+)\s*(.*)', line)
            if m:
                addr = int(m[1], 16)
                size = len(m[2].split())
                asm = m[3]
                instructions.append((addr, asm))
                if re.match(r'(callq?|bl|blr)\s', asm):
                    hardware_returns.add(addr+size)
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
(out/'results.json').write_text(json.dumps(results, indent=2)+'\n')
raise SystemExit(any(r['status'] != 'PASS' for r in results))
