#!/bin/bash
set -u
ulimit -c 0
root=/root/sym_cjcj_llvm_1_implement_r5668195885
cd "$root" || exit 2
export CCACHE_DIR=/root/.ccache CCACHE_NOHASHDIR=1 PATH=/usr/lib/ccache:$PATH
uptime > rebuild-uptime-before.txt
for arm in green producer consumer restored; do
 (
  start=$SECONDS
  mkdir -p "$arm/initial-bin"
  cp "$arm/build/bin/"{llc,opt,llvm-dis} "$arm/initial-bin/"
  mv "$arm/product.sha256" "$arm/product.initial-paths.sha256"
  export CCACHE_BASEDIR="$root/$arm"
  maps="-ffile-prefix-map=$root/$arm/src=/usr/src/cangjie-llvm -fdebug-prefix-map=$root/$arm/src=/usr/src/cangjie-llvm -fmacro-prefix-map=$root/$arm/src=/usr/src/cangjie-llvm -ffile-prefix-map=$root/$arm/build=/usr/build/cangjie-llvm -fdebug-prefix-map=$root/$arm/build=/usr/build/cangjie-llvm -fmacro-prefix-map=$root/$arm/build=/usr/build/cangjie-llvm"
  cmake -S "$root/$arm/src/llvm" -B "$root/$arm/build" -DCMAKE_C_FLAGS="$maps" -DCMAKE_CXX_FLAGS="$maps" > "$arm/reconfigure.log" 2>&1
  rc=$?; echo "$rc" > "$arm/reconfigure.rc"
  if [ "$rc" = 0 ]; then
    ninja -C "$root/$arm/build" -j"$(nproc)" -l150 llc opt FileCheck not llvm-dis split-file llvm-readobj llvm-objdump llvm-as llvm-readelf count llvm-config > "$arm/rebuild.log" 2>&1
    rc=$?;echo "$rc" > "$arm/rebuild.rc"
    if [ "$rc" = 0 ]; then sha256sum "$arm/build/bin/"{llc,opt,FileCheck,not,llvm-dis} > "$arm/product.sha256"; fi
  fi
  echo "$((SECONDS-start))" > "$arm/rebuild-wall.txt"
 ) &
done
wait
uptime > rebuild-uptime-after.txt
