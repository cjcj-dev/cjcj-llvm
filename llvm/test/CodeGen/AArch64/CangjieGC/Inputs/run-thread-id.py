#!/usr/bin/env python3
import argparse, hashlib, pathlib, struct, subprocess, sys, json
parser = argparse.ArgumentParser(description="Run actual llc AArch64 thread-id emission under QEMU")
parser.add_argument('--llvm-bin', type=pathlib.Path, required=True)
parser.add_argument('--output-dir', type=pathlib.Path, required=True)
parser.add_argument('--clang', default='clang')
parser.add_argument('--linker', default='ld.lld')
parser.add_argument('--qemu', default='qemu-aarch64')
args = parser.parse_args()
bin = args.llvm_bin.resolve()
out = args.output_dir.resolve()
out.mkdir(parents=True, exist_ok=True)
src = pathlib.Path(__file__).resolve().parent
commands = [
 [str(bin/'llc'), '--cangjie-pipeline', '-mtriple=aarch64-unknown-linux-gnu', '-filetype=obj', str(src.parent/'runtime-thread-id.ll'), '-o', str(out/'thread.o')],
 [args.clang, '--target=aarch64-linux-gnu', '-c', str(src/'runtime-thread-id-start.s'), '-o', str(out/'start.o')],
 [args.linker, '-m', 'aarch64elf', '-static', '-e', '_start', str(out/'start.o'), str(out/'thread.o'), '-o', str(out/'thread-test')],
]
for command in commands:
 r = subprocess.run(command, capture_output=True)
 print('COMMAND', command, 'RC', r.returncode, flush=True)
 if r.returncode:
  print(r.stderr.decode(errors='replace')); sys.exit(2)
for path in [bin/'llc', out/'thread.o', out/'start.o',out/'thread-test']:
 print('SHA256', hashlib.sha256(path.read_bytes()).hexdigest(),path,flush=True)
r = subprocess.run([str(bin/'llvm-objdump'), '-d', str(out/'thread.o')], capture_output=True)
(out/'disassembly.txt').write_bytes(r.stdout)
r = subprocess.run([args.qemu, str(out/'thread-test')],capture_output=True)
print('QEMU_RC',r.returncode,'BYTES',len(r.stdout),flush=True)
if r.returncode or len(r.stdout)!=24:
 print(r.stderr.decode(errors='replace'));sys.exit(2)
values=struct.unpack('<QQQ',r.stdout)
results=[]
for name,actual,expected in zip(['null','high-nonnull-low32-zero','ordinary-nonnull'],values,[0,0x1234,0x5678]):
 ok=actual==expected
 print('ASSERT',name,'actual='+hex(actual),'expected='+hex(expected),'PASS' if ok else 'FAIL',flush=True)
 results.append(dict(name=name,actual=actual,expected=expected,passed=ok))
(out/'result.json').write_text(json.dumps(results,indent=2)+'\n')
sys.exit(0 if all(x['passed'] for x in results) else 1)
