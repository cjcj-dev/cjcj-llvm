#!/bin/bash
set -u
ulimit -c 0
root=/root/sym_cjcj_llvm_1_implement_r5668195885
arm=${1:?arm}
export PYTHONPATH="$root/python-deps${PYTHONPATH:+:$PYTHONPATH}"
cd "$root/$arm" || exit 2
ninja -C build -j"$(nproc)" -l150 llvm-readelf count llvm-config > test-tools-build.log 2>&1
echo "$?" > test-tools-build.rc
start=$SECONDS
uptime > test-uptime-before.txt
sha256sum build/bin/{llc,opt,FileCheck} > test-input.sha256
python3 build/bin/llvm-lit -j "$(nproc)" -sv --timeout=120 -o lit.json src/llvm/test/CodeGen/X86/CangjieGC > lit.log 2>&1
echo "$?" > lit.rc
for level in O0 O2; do
  build/bin/llc --cangjie-pipeline -mtriple=x86_64 -"$level" -print-after=cj-barrier-lowering -o "static-$level.s" < src/llvm/test/CodeGen/X86/CangjieGC/static-write-all-phases.ll > "static-$level.ir" 2>&1
  echo "$?" > "static-$level-llc.rc"
  build/bin/FileCheck src/llvm/test/CodeGen/X86/CangjieGC/static-write-all-phases.ll --check-prefix=IR --implicit-check-not=gcNoRunning < "static-$level.ir" > "static-$level-ir-check.log" 2>&1
  echo "$?" > "static-$level-ir-check.rc"
  build/bin/FileCheck src/llvm/test/CodeGen/X86/CangjieGC/static-write-all-phases.ll --check-prefix=ASM --implicit-check-not=GetGCPhase < "static-$level.s" > "static-$level-asm-check.log" 2>&1
  echo "$?" > "static-$level-asm-check.rc"
done
uptime > test-uptime-after.txt
echo "$((SECONDS-start))" > test-wall.txt
