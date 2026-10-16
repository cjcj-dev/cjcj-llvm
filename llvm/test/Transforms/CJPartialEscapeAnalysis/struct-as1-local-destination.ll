; RUN: opt -passes=cj-pea -S < %s | FileCheck %s

target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

declare void @llvm.cj.gcwrite.struct.p0i8.i64(i8 addrspace(1)*, i8 addrspace(1)*, i8*, i64)

define void @local_destination(i8* %src) #0 gc "cangjie" {
; CHECK-LABEL: define void @local_destination(
; CHECK-NOT: call void @llvm.cj.gcwrite.struct
; CHECK: call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 8 %as1, i8* align 8 %src, i64 8, i1 false)
; CHECK-NOT: call void @llvm.cj.gcwrite.struct
; CHECK: ret void
  %dst = alloca i8, i64 8, align 8
  %as1 = addrspacecast i8* %dst to i8 addrspace(1)*
  call void @llvm.cj.gcwrite.struct.p0i8.i64(i8 addrspace(1)* %as1, i8 addrspace(1)* %as1, i8* %src, i64 8)
  ret void
}
attributes #0 = { "hasMD" }
