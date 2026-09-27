; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu -O2 -filetype=obj %s -o %t.o
; RUN: %python %S/Inputs/check-call-root-stack.py %t.o
; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu -O2 --max-registers-for-gc-values=64 -filetype=obj %s -o %t.regalloc.o
; RUN: %python %S/Inputs/check-call-root-stack.py %t.regalloc.o
;
; HotSpot cpu/x86/x86.ad:43-49: save live references at the call site.
; frame_x86.inline.hpp:455-464: compiled-frame roots do not depend on a
; callee's register-save slots. Check actual ELF call-return stackmap rows.

target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"

define void @call_root_stack(i8 addrspace(1)* %root, i8 addrspace(1)** %out) gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, void ()* @checkpoint, i32 0, i32 0)
  store i8 addrspace(1)* %root, i8 addrspace(1)** %out
  ret void
}

declare token @llvm.cj.gc.statepoint(...)
declare void @checkpoint()
