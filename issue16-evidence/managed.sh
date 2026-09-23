#!/bin/bash
set -u
ulimit -c 0
cd /root/sym_cjcj_llvm_16_implement_r5788821149 || exit 2
arm=$1
sdk=$PWD/sdk-$arm
host=/root/sym_cjcj_48_implement_r5685150408/host/runtime/lib/linux_x86_64_cjnative
mkdir -p "managed/$arm/temps"
start=$SECONDS
export CANGJIE_HOME="$sdk"
export LD_LIBRARY_PATH="$host:$sdk/third_party/llvm/lib:$sdk/lib/linux_x86_64_cjnative"
"$sdk/bin/cjcj-stage1" roundtrip.cj -O2 --static-std --save-temps "$PWD/managed/$arm/temps" --verbose -o "$PWD/managed/$arm/roundtrip" > "managed/$arm/build.log" 2>&1
rc=$?; echo "$rc" > "managed/$arm/build.rc"
if [ "$rc" = 0 ]; then sha256sum "managed/$arm/roundtrip" > "managed/$arm/elf.sha256"; fi
echo "$((SECONDS-start))" > "managed/$arm/build-wall.txt"
echo "$arm managed_compile_rc=$rc wall=$((SECONDS-start))"
