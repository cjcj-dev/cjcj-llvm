; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu -O2 -filetype=obj %s -o %t.o
; RUN: %python %S/Inputs/check-call-root-stack.py %t.o
; RUN: %python %S/Inputs/check-call-root-stack.py %t.o invoke_root_stack
; RUN: %python %S/Inputs/check-call-root-stack.py %t.o derived_root_stack
; RUN: %python %S/Inputs/check-call-root-stack.py %t.o no_root_stack
; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu -O2 --max-registers-for-gc-values=64 -filetype=obj %s -o %t.regalloc.o
; RUN: %python %S/Inputs/check-call-root-stack.py %t.regalloc.o
; RUN: %python %S/Inputs/check-call-root-stack.py %t.regalloc.o invoke_root_stack
; RUN: %python %S/Inputs/check-call-root-stack.py %t.regalloc.o derived_root_stack
; RUN: llvm-objdump -d --no-show-raw-insn --disassemble-symbols=indirect_root_stack %t.o > %t.dis
; RUN: %python %S/Inputs/check-call-root-stack.py %t.o indirect_root_stack %t.dis
; RUN: llc --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu -O2 -filetype=obj %s -o %t.a64.o
; RUN: %python %S/Inputs/check-call-root-stack.py %t.a64.o
; RUN: %python %S/Inputs/check-call-root-stack.py %t.a64.o invoke_root_stack
; RUN: %python %S/Inputs/check-call-root-stack.py %t.a64.o derived_root_stack
; RUN: %python %S/Inputs/check-call-root-stack.py %t.a64.o no_root_stack
; RUN: llvm-objdump -d --no-show-raw-insn --disassemble-symbols=indirect_root_stack %t.a64.o > %t.a64.dis
; RUN: %python %S/Inputs/check-call-root-stack.py %t.a64.o indirect_root_stack %t.a64.dis
;
; HotSpot cpu/x86/x86.ad:43-49: save live references at the call site.
; frame_x86.inline.hpp:455-464: compiled-frame roots do not depend on a
; callee's register-save slots. Check actual ELF call-return stackmap rows.

target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"

define void @call_root_stack(i8 addrspace(1)* %root, i8 addrspace(1)** %out) gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, void ()* @checkpoint, i32 0, i32 0) [ "gc-live"(i8 addrspace(1)* %root) ]
  %relocated = call i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token %token, i32 0, i32 0)
  store i8 addrspace(1)* %relocated, i8 addrspace(1)** %out
  ret void
}

declare token @llvm.cj.gc.statepoint(...)
declare void @checkpoint()

define void @invoke_root_stack(i8 addrspace(1)* %root, i8 addrspace(1)** %out) gc "cangjie" personality i32 (...)* @__gxx_personality_v0 {
entry:
  %token = invoke token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, void ()* @checkpoint, i32 0, i32 0) [ "gc-live"(i8 addrspace(1)* %root) ] to label %normal unwind label %exception
normal:
  %normal.root = call i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token %token, i32 0, i32 0)
  store i8 addrspace(1)* %normal.root, i8 addrspace(1)** %out
  ret void
exception:
  %exception.value = landingpad token cleanup
  %exception.root = call i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token %exception.value, i32 0, i32 0)
  store i8 addrspace(1)* %exception.root, i8 addrspace(1)** %out
  ret void
}

define void @derived_root_stack(i8 addrspace(1)* %root, i8 addrspace(1)** %out, i64 %index) gc "cangjie" {
entry:
  %derived = getelementptr i8, i8 addrspace(1)* %root, i64 %index
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, void ()* @checkpoint, i32 0, i32 0) [ "gc-live"(i8 addrspace(1)* %root, i8 addrspace(1)* %derived) ]
  %relocated = call i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token %token, i32 0, i32 1)
  store i8 addrspace(1)* %relocated, i8 addrspace(1)** %out
  ret void
}

declare i32 @__gxx_personality_v0(...)

; A normal call with no live GC values needs no root slot.
define void @no_root_stack() gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, void ()* @checkpoint, i32 0, i32 0)
  ret void
}

declare i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token, i32 immarg, i32 immarg)

define void @indirect_root_stack(i8 addrspace(1)* %root, i8 addrspace(1)** %out, void ()* %callee) gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, void ()* %callee, i32 0, i32 0) [ "gc-live"(i8 addrspace(1)* %root) ]
  %relocated = call i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token %token, i32 0, i32 0)
  store i8 addrspace(1)* %relocated, i8 addrspace(1)** %out
  ret void
}
