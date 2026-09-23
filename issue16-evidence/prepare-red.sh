#!/bin/bash
set -eu
ulimit -c 0
cd /root/sym_cjcj_llvm_16_implement_r5788821149
mkdir -p green/bin
cp candidate/bin/{llc,opt,FileCheck} green/bin/
cp candidate.sha256 green/product.sha256
for file in candidate-*; do
  if [ -f "$file" ]; then cp "$file" green/; fi
done
cp -a candidate-src producer-src
(cd producer-src && patch -p1 < ../producer.diff) > producer-patch.log
(cd candidate-src && patch -p1 < ../consumer.diff) > consumer-patch.log
