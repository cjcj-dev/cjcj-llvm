#!/bin/bash
set -u
ulimit -c 0
root=/root/sym_cjcj_llvm_1_implement_r5668195885
arm=${1:?arm}
old=/root/sym_cangjie_runtime_560b_sym_cangjie_runtime_564_implement_r5664061027
cd "$root" || exit 2
mkdir -p "$arm/probe"
if [ "$arm" = baseline ]; then
  SDK=$old/gate-sdk
else
  SDK=$root/$arm/sdk
  if [ ! -d "$SDK" ]; then
    cp -a --reflink=auto "$old/gate-sdk" "$SDK"
    rm "$SDK/third_party/llvm/bin/llc" "$SDK/third_party/llvm/bin/opt"
    cp "$root/$arm/build/bin/llc" "$root/$arm/build/bin/opt" "$SDK/third_party/llvm/bin/"
  fi
fi
export CANGJIE_HOME="$SDK"
export LD_LIBRARY_PATH="$old/host/runtime/lib/linux_x86_64_cjnative:$SDK/tools/lib:$old/host/third_party/llvm/lib"
uptime > "$arm/probe/uptime-before.txt"
sha256sum "$SDK/bin/cjc" "$SDK/third_party/llvm/bin/llc" "$SDK/third_party/llvm/bin/opt" "$old/host/runtime/lib/linux_x86_64_cjnative/libcangjie-runtime.so" "$old/host/runtime/lib/linux_x86_64_cjnative/libboundscheck.so" global_slot_probe.cj > "$arm/probe/input.sha256"
for optlevel in O0 O2; do
  (
    cd "$root/$arm/probe" || exit 2
    mkdir -p "$optlevel/temps"
    cp "$root/global_slot_probe.cj" "$optlevel/"
    cd "$optlevel" || exit 2
    started=$SECONDS
    "$SDK/bin/cjc" global_slot_probe.cj -"$optlevel" -g --static-std --save-temps "$PWD/temps" -V -o "$PWD/global_slot_probe" > compile.log 2>&1
    rc=$?; echo "$rc" > compile.rc
    if [ "$rc" = 0 ]; then
      sha256sum global_slot_probe > elf.sha256
      objdump -drC global_slot_probe > disassembly.txt
      echo "$?" > objdump.rc
      nm --defined-only global_slot_probe > defined.nm
      echo "$?" > nm.rc
    fi
    echo "$((SECONDS-started))" > wall.txt
  ) &
done
wait
uptime > "$arm/probe/uptime-after.txt"
