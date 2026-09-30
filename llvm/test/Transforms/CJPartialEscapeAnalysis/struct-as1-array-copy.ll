; RUN: opt -passes=cj-pea -S < %s | FileCheck %s

target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

declare void @llvm.cj.array.copy.struct.i64(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)*, i64)

define void @array_heap_destination(i8 addrspace(1)* %heap) #0 gc "cangjie" {
; CHECK-LABEL: define void @array_heap_destination(
; CHECK-NOT: @llvm.memmove
; CHECK: call void @llvm.cj.array.copy.struct.i64(i8 addrspace(1)* %heap, i8 addrspace(1)* %heap, i8 addrspace(1)* %as1, i8 addrspace(1)* %as1, i64 8)
; CHECK-NOT: @llvm.memmove
; CHECK: ret void
  %src = alloca i8, i64 8, align 8
  %as1 = addrspacecast i8* %src to i8 addrspace(1)*
  call void @llvm.cj.array.copy.struct.i64(i8 addrspace(1)* %heap, i8 addrspace(1)* %heap, i8 addrspace(1)* %as1, i8 addrspace(1)* %as1, i64 8)
  ret void
}
attributes #0 = { "hasMD" }
