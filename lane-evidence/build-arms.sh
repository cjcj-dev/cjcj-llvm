#!/bin/bash
set -u
ulimit -c 0
root=/root/sym_cjcj_llvm_1_implement_r5668195885
cd "$root" || exit 2
export CCACHE_DIR=/root/.ccache CCACHE_NOHASHDIR=1
export PATH=/usr/lib/ccache:$PATH
uptime > build-uptime-before.txt
start=$SECONDS
mkdir -p src
 tar -xzf source.tar.gz -C src
cp tests/static-*.ll src/llvm/test/CodeGen/X86/CangjieGC/
for arm in green producer consumer restored; do
  mkdir -p "$arm"
  cp -a --reflink=auto src "$arm/src"
  if [ "$arm" = producer ] || [ "$arm" = consumer ]; then
    (cd "$arm/src" && patch -p1 < "$root/$arm.diff") > "$arm/patch.log" 2>&1 || exit 3
  fi
  (
    started=$SECONDS
    export CCACHE_BASEDIR="$root/$arm/src"
    maps="-ffile-prefix-map=$CCACHE_BASEDIR=/usr/src/cangjie-llvm -fdebug-prefix-map=$CCACHE_BASEDIR=/usr/src/cangjie-llvm -fmacro-prefix-map=$CCACHE_BASEDIR=/usr/src/cangjie-llvm"
    cmake -S "$root/$arm/src/llvm" -B "$root/$arm/build" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache -DCMAKE_C_FLAGS="$maps" -DCMAKE_CXX_FLAGS="$maps" -DLLVM_TARGETS_TO_BUILD=X86 -DLLVM_ENABLE_ASSERTIONS=ON -DLLVM_INCLUDE_TESTS=ON -DLLVM_BUILD_LLVM_DYLIB=ON -DLLVM_LINK_LLVM_DYLIB=OFF > "$arm/configure.log" 2>&1
    rc=$?; echo "$rc" > "$arm/configure.rc"
    if [ "$rc" = 0 ]; then
      ninja -C "$root/$arm/build" -j"$(nproc)" -l150 llc opt FileCheck not llvm-dis split-file llvm-readobj llvm-objdump llvm-as > "$arm/build.log" 2>&1
      rc=$?; echo "$rc" > "$arm/build.rc"
      if [ "$rc" = 0 ]; then sha256sum "$arm/build/bin/"{llc,opt,FileCheck,not,llvm-dis} > "$arm/product.sha256"; fi
    fi
    echo "$((SECONDS-started))" > "$arm/wall.txt"
  ) &
done
wait
uptime > build-uptime-after.txt
echo "$((SECONDS-start))" > build-wall.txt
