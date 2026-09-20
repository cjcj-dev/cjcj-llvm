; RUN: llc --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu -debug-only=branch-relaxation -o /dev/null < %s 2>&1 | FileCheck %s
; REQUIRES: aarch64-registered-target, asserts
;
; The branch relaxation pass calls AArch64InstrInfo's real size estimator.
; This array block comprises 32 bytes of frame/call bookkeeping plus the
; twelve emitted TLAB instructions (48 bytes). Keeping the old 52 estimate
; makes this block 0x54 and fails here, independently of assembly text checks.
; CHECK: Basic blocks before relaxation
; CHECK-NEXT: %bb.0 offset=00000000 size=0x50

target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
define i8 addrspace(1)* @allocate_array(i8* %type, i64 %length, i64 %size) gc "cangjie" {
  %token = call token (...) @llvm.cj.gc.statepoint(i64 6, i32 0, i8 addrspace(1)* (i8*, i64, i64)* @CJ_MCC_NewArray, i32 3, i32 0, i8* %type, i64 %length, i64 %size)
  %p = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  ret i8 addrspace(1)* %p
}
declare i8 addrspace(1)* @CJ_MCC_NewArray(i8*, i64, i64)
declare token @llvm.cj.gc.statepoint(...)
declare i8 addrspace(1)* @llvm.cj.gc.result(token)
