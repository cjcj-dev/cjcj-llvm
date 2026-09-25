; RUN: llc --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu -debug-only=branch-relaxation -o /dev/null < %s 2>&1 | FileCheck %s
; REQUIRES: aarch64-registered-target, asserts
;
; emitMccNewObjectForCopyGC replaces this call with 11 instructions (44 bytes).
; The block is a 4-byte spill, that sequence, a 4-byte reload and ret: 0x38.
; Counting the call as one BL prints size=0x10 and fails here.
; CHECK: Basic blocks before relaxation
; CHECK-NEXT: %bb.0 offset=00000000 size=0x38

target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
define i8 addrspace(1)* @allocate_object(i8* %type, i32 %size) gc "cangjie" {
  %p = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* %type, i32 %size)
  ret i8 addrspace(1)* %p
}
declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
