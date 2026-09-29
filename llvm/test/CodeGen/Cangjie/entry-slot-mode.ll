; REQUIRES: x86-registered-target, aarch64-registered-target
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -filetype=obj %s -o %t.x86.o
; RUN: llvm-readobj --sections --symbols %t.x86.o | FileCheck %s --implicit-check-not=.Lmethod_desc --implicit-check-not=.cjmetadata
; RUN: llc -mtriple=aarch64-unknown-linux-gnu -filetype=obj %s -o %t.arm.o
; RUN: llvm-readobj --sections --symbols %t.arm.o | FileCheck %s --implicit-check-not=.Lmethod_desc --implicit-check-not=.cjmetadata
;
; Without the Cangjie pipeline, neither slots nor their referenced metadata
; are emitted. This must remain a real object test: assembly text alone can
; hide an unresolved temporary descriptor symbol.
; Ordinary LLVM stackmaps remain valid here; they are not Cangjie frame heads.
; CHECK-DAG: Name: .llvm_stackmaps
; CHECK-DAG: Name: plain_managed_leaf
; CHECK-DAG: Name: plain_managed_nonleaf
; CHECK-DAG: Name: external_callee

define i32 @plain_managed_leaf() "leaf-function" gc "cangjie" {
  ret i32 1
}

define void @plain_managed_nonleaf() gc "cangjie" {
  call void @external_callee()
  ret void
}
declare void @external_callee()
