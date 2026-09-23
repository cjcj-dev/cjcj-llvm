#!/bin/bash
set -eu
ulimit -c 0
cd /root/sym_cjcj_llvm_16_implement_r5788821149
mkdir -p baseline-src
tar -xzf source.tar.gz -C baseline-src
tar -xzf third-party.tar.gz -C baseline-src
cp -a baseline-src candidate-src
cp CJBarrierLowering.cpp candidate-src/llvm/lib/CodeGen/CJBarrierLowering.cpp
for arm in baseline candidate; do
  cp llvm/test/CodeGen/X86/CangjieGC/heap-domain-*.ll "$arm-src/llvm/test/CodeGen/X86/CangjieGC/"
done
