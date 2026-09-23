#!/bin/bash
set -eu
cd /root/sym_cjcj_llvm_16_implement_r5788821149
for arm in "$@"; do
 for tool in ld.lld lld-link ld64.lld; do
  cp /root/sdkdepot/b99430a618af-1ecb811801ca/third_party/llvm/bin/$tool "$arm/bin/$tool"
 done
 cp -L /root/sym_cjcj_llvm_13_implement_r5788356493/candidate/bin/wasm-ld "$arm/bin/wasm-ld"
done
