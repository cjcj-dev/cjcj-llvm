#!/bin/bash
set -u
ulimit -c 0
cd /root/sym_cjcj_llvm_16_implement_r5788821149 || exit 2
export CCACHE_DIR=/root/.ccache CCACHE_NOHASHDIR=1
for arm in "$@"; do
  (
    start=$SECONDS
    export CCACHE_BASEDIR="$PWD/$arm-src"
    uptime > "$arm-uptime-before.txt"
    cmake -S "$arm-src/llvm" -B "$arm" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache '-DLLVM_TARGETS_TO_BUILD=X86;AArch64' -DLLVM_ENABLE_ASSERTIONS=OFF -DLLVM_INCLUDE_TESTS=ON > "$arm-configure.log" 2>&1
    rc=$?; echo "$rc" > "$arm-configure.rc"
    if [ "$rc" = 0 ]; then
      cmake --build "$arm" -j"$(nproc)" --target llc opt FileCheck not llvm-as llvm-dis count llvm-config llvm-readobj llvm-objdump llvm-link split-file -- -l150 > "$arm-build.log" 2>&1
      rc=$?; echo "$rc" > "$arm-build.rc"
      if [ "$rc" = 0 ]; then sha256sum "$arm"/bin/{llc,opt,FileCheck} > "$arm.sha256"; fi
    fi
    echo "$((SECONDS-start))" > "$arm-wall.txt"
    uptime > "$arm-uptime-after.txt"
    echo "$arm rc=$rc wall=$((SECONDS-start)) jobs=$(nproc)"
  ) &
done
wait
