; RUN: llc -O0 --cangjie-pipeline -cj-stack-grow=false -mtriple=aarch64-unknown-linux-gnu -filetype=obj < %S/../../X86/cj-stack-pointer-map.ll -o %t.off.o
; RUN: %python %S/../../X86/Inputs/check-cj-stack-pointer-map.py %t.off.o
; RUN: llc -O0 --cangjie-pipeline -cj-stack-grow=true -mtriple=aarch64-unknown-linux-gnu -filetype=obj < %S/../../X86/cj-stack-pointer-map.ll -o %t.on.o
; RUN: %python %S/../../X86/Inputs/check-cj-stack-pointer-map.py %t.on.o
; RUN: llc -O2 --cangjie-pipeline -cj-stack-grow=false -mtriple=aarch64-unknown-linux-gnu -filetype=obj < %S/../../X86/cj-stack-pointer-map.ll -o %t.opt.o
; RUN: %python %S/../../X86/Inputs/check-cj-stack-pointer-map.py %t.opt.o
;
; Both supported 64-bit calling conventions must retain the incoming sret
; pointer at the call return PC with stack growth disabled.
