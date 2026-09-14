#!/bin/bash
set -u
ulimit -c 0
root=/root/sym_cjcj_llvm_1_implement_r5668195885
arm=$1
cut=$2
cd "$root/$arm" || exit 2
out=$root/$arm/roundtrip
mkdir -p "$out"
export PYTHONPATH="$root/python-deps" CCACHE_DIR=/root/.ccache
uptime > "$out/uptime-before.txt"
sha256sum src/llvm/lib/CodeGen/CJBarrierLowering.cpp > "$out/source-before.sha256"
for phase in before cut restored; do
 mkdir -p "$out/$phase"
 if [ "$phase" = cut ]; then
  (cd src && patch -p1 < "$root/$cut.diff") > "$out/$phase/patch.log" 2>&1 || exit 3
 elif [ "$phase" = restored ]; then
  (cd src && patch -R -p1 < "$root/$cut.diff") > "$out/$phase/patch.log" 2>&1 || exit 4
 fi
 start=$SECONDS
 ninja -C build -j"$(nproc)" -l150 llc opt FileCheck > "$out/$phase/build.log" 2>&1
 rc=$?; echo "$rc" > "$out/$phase/build.rc"
 [ "$rc" = 0 ] || exit 5
 sha256sum build/bin/{llc,opt,FileCheck} > "$out/$phase/products.sha256"
 python3 build/bin/llvm-lit -j"$(nproc)" -sv --timeout=120 -o "$out/$phase/lit.json" src/llvm/test/CodeGen/X86/CangjieGC > "$out/$phase/lit.log" 2>&1
 echo "$?" > "$out/$phase/lit.rc"
 for level in O0 O2; do
  build/bin/llc --cangjie-pipeline -mtriple=x86_64 -"$level" -print-after=cj-barrier-lowering -o "$out/$phase/$level.s" < src/llvm/test/CodeGen/X86/CangjieGC/static-write-all-phases.ll > "$out/$phase/$level.ir" 2>&1
  echo "$?" > "$out/$phase/$level-llc.rc"
  build/bin/FileCheck src/llvm/test/CodeGen/X86/CangjieGC/static-write-all-phases.ll --check-prefix=IR --implicit-check-not=gcNoRunning < "$out/$phase/$level.ir" > "$out/$phase/$level-ir-check.log" 2>&1
  echo "$?" > "$out/$phase/$level-ir-check.rc"
  build/bin/FileCheck src/llvm/test/CodeGen/X86/CangjieGC/static-write-all-phases.ll --check-prefix=ASM --implicit-check-not=GetGCPhase < "$out/$phase/$level.s" > "$out/$phase/$level-asm-check.log" 2>&1
  echo "$?" > "$out/$phase/$level-asm-check.rc"
 done
 echo "$((SECONDS-start))" > "$out/$phase/wall.txt"
done
sha256sum src/llvm/lib/CodeGen/CJBarrierLowering.cpp > "$out/source-after.sha256"
cmp "$out/source-before.sha256" "$out/source-after.sha256"; echo "$?" > "$out/source-restore.rc"
cmp "$out/before/products.sha256" "$out/restored/products.sha256"; echo "$?" > "$out/product-restore.rc"
uptime > "$out/uptime-after.txt"
