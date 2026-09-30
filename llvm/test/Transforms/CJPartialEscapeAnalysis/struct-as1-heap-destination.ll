; RUN: opt -passes=cj-pea -S < %s | FileCheck %s

target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

declare void @llvm.cj.gcwrite.struct.p0i8.i64(i8 addrspace(1)*, i8 addrspace(1)*, i8*, i64)

; A source alloca on the AS1 rewrite queue does not authorize a heap write.
define void @heap_destination(i8 addrspace(1)* %heap) #0 gc "cangjie" {
; CHECK-LABEL: define void @heap_destination(
; CHECK-NOT: @llvm.memcpy
; CHECK: call void @llvm.cj.gcwrite.struct.p0i8.i64(i8 addrspace(1)* %heap, i8 addrspace(1)* %dst, i8* %src, i64 8)
; CHECK-NOT: @llvm.memcpy
; CHECK: ret void
  %src = alloca i8, i64 8, align 8
  %as1 = addrspacecast i8* %src to i8 addrspace(1)*
  %dst = getelementptr i8, i8 addrspace(1)* %heap, i64 8
  call void @llvm.cj.gcwrite.struct.p0i8.i64(i8 addrspace(1)* %heap, i8 addrspace(1)* %dst, i8* %src, i64 8)
  ret void
}
attributes #0 = { "hasMD" }
