; RUN: llc --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu -debug-only=branch-relaxation -o /dev/null < %s 2>&1 | FileCheck %s
; REQUIRES: aarch64-registered-target, asserts
;
; An indirect call is not a global sentinel. It stays one BLR. The object
; size branch must not change this block.
; CHECK: Basic blocks before relaxation
; CHECK-NEXT: %bb.0 offset=00000000 size=0x1c

target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
define i8 addrspace(1)* @allocate_indirect(i8 addrspace(1)* (i8*, i32)* %fp, i8* %type, i32 %size) gc "cangjie" {
  %p = call i8 addrspace(1)* %fp(i8* %type, i32 %size)
  ret i8 addrspace(1)* %p
}
