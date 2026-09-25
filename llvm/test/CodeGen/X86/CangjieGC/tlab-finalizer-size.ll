; RUN: llc --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu -debug-only=branch-relaxation -o /dev/null < %s 2>&1 | FileCheck %s
; REQUIRES: aarch64-registered-target, asserts
;
; Same object sequence plus bl CJ_MCC_OnFinalizerCreated: 12 instructions, 48 bytes.
; Spill + sequence + reload + ret is 0x3c. A 4-byte call estimate prints 0x10.
; CHECK: Basic blocks before relaxation
; CHECK-NEXT: %bb.0 offset=00000000 size=0x3c

target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
define i8 addrspace(1)* @allocate_finalizer(i8* %type, i32 %size) gc "cangjie" {
  %p = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* %type, i32 %size)
  ret i8 addrspace(1)* %p
}
declare i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8*, i32)
declare void @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)*)
