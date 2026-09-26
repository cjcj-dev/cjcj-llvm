; RUN: llc --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu -debug-only=branch-relaxation -o /dev/null < %s 2>&1 | FileCheck %s
; REQUIRES: aarch64-registered-target, asserts
;
; Tail calls lower to one B. Counting the TCRETURNdi as the 48-byte finalizer
; fast path prints size=0x30 and fails here.
; CHECK: Basic blocks before relaxation
; CHECK-NEXT: %bb.0 offset=00000000 size=0x4

target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
define i8 addrspace(1)* @allocate_finalizer_tail(i8* %type, i32 %size) gc "cangjie" {
  %p = tail call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* %type, i32 %size)
  ret i8 addrspace(1)* %p
}
declare i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8*, i32)
declare void @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)*)
