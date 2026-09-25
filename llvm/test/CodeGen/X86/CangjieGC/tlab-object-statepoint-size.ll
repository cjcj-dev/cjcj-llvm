; RUN: llc --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu -debug-only=branch-relaxation -o /dev/null < %s 2>&1 | FileCheck %s
; REQUIRES: aarch64-registered-target, asserts
;
; Statepoint id 0 is outlined to an internal fast function whose body is still
; a call to CJ_MCC_NewObject. The caller block stays 0x24. The outlined block
; is the same 11-instruction replacement as the direct call: 0x38.
; CHECK: Basic blocks before relaxation
; CHECK-NEXT: %bb.0 offset=00000000 size=0x24
; CHECK: Basic blocks before relaxation
; CHECK-NEXT: %bb.0 offset=00000000 size=0x38

target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
define i8 addrspace(1)* @allocate_object_sp(i8* %type, i32 %size) gc "cangjie" {
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i32)* @CJ_MCC_NewObject, i32 2, i32 0, i8* %type, i32 %size)
  %p = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  ret i8 addrspace(1)* %p
}
declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare token @llvm.cj.gc.statepoint(...)
declare i8 addrspace(1)* @llvm.cj.gc.result(token)
