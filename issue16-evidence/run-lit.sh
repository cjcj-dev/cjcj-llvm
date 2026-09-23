#!/bin/bash
set -u
ulimit -c 0
cd /root/sym_cjcj_llvm_16_implement_r5788821149 || exit 2
for arm in "$@"; do
 (
  start=$SECONDS
  uptime > "$arm-lit-uptime-before.txt"
  python3 "$arm/bin/llvm-lit" -v -j"$(nproc)" --timeout=120 -o "$arm-lit.json" "$arm/test/CodeGen/X86/CangjieGC" "$arm/test/Transforms/CJBarrierOpt" "$arm/test/Transforms/CJBarrierSplit" "$arm/test/Transforms/CJIRVerifier" > "$arm-lit.log" 2>&1
  rc=$?; echo "$rc" > "$arm-lit.rc"
  echo "$((SECONDS-start))" > "$arm-lit-wall.txt"
  uptime > "$arm-lit-uptime-after.txt"
  echo "$arm lit_rc=$rc wall=$((SECONDS-start))"
  tail -18 "$arm-lit.log"
 ) &
done
wait
