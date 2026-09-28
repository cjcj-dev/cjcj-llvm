; RUN: opt -passes=cj-generic-intrinsic-opt -S < %s | FileCheck %s
; RUN: opt -cj-generic-intrinsic-opt -S < %s | FileCheck %s
; Actual TypeInfo producer field types, in runtime order (64-bit ABI).
target datalayout = "e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, i8**, i8*, i8* }

; CHECK-LABEL: define void @assign(
; CHECK: getelementptr %TypeInfo, %TypeInfo* %{{.*}}, i32 0, i32 4
; CHECK: load i32, i32* %{{.*}}
; CHECK: getelementptr i8, i8 addrspace(1)* %dst, i32 8
; CHECK: getelementptr i8, i8 addrspace(1)* %src, i32 8
; CHECK: call void @llvm.memcpy.
define void @assign(i8* %ti) gc "cangjie" {
  %d = alloca [24 x i8], align 8
  %s = alloca [24 x i8], align 8
  %dp = bitcast [24 x i8]* %d to i8*
  %sp = bitcast [24 x i8]* %s to i8*
  %dst = addrspacecast i8* %dp to i8 addrspace(1)*
  %src = addrspacecast i8* %sp to i8 addrspace(1)*
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* %src, i8* %ti)
  ret void
}

; CHECK-LABEL: define void @read_generic(
; CHECK: getelementptr i8, i8 addrspace(1)* %dst, i32 8
; CHECK: call void @llvm.memcpy.
define void @read_generic(i32 %size) gc "cangjie" {
  %d = alloca [24 x i8], align 8
  %s = alloca [24 x i8], align 8
  %dp = bitcast [24 x i8]* %d to i8*
  %sp = bitcast [24 x i8]* %s to i8*
  %dst = addrspacecast i8* %dp to i8 addrspace(1)*
  %src = addrspacecast i8* %sp to i8 addrspace(1)*
  call void @llvm.cj.gcread.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* %src, i8 addrspace(1)* %src, i32 %size)
  ret void
}

; CHECK-LABEL: define void @write_generic(
; CHECK: getelementptr i8, i8 addrspace(1)* %src, i32 8
; CHECK: call void @llvm.memcpy.
define void @write_generic(i32 %size) gc "cangjie" {
  %d = alloca [24 x i8], align 8
  %s = alloca [24 x i8], align 8
  %dp = bitcast [24 x i8]* %d to i8*
  %sp = bitcast [24 x i8]* %s to i8*
  %dst = addrspacecast i8* %dp to i8 addrspace(1)*
  %src = addrspacecast i8* %sp to i8 addrspace(1)*
  call void @llvm.cj.gcwrite.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* %dst, i8 addrspace(1)* %src, i32 %size)
  ret void
}
declare void @llvm.cj.assign.generic(i8 addrspace(1)*, i8 addrspace(1)*, i8*)
declare void @llvm.cj.gcread.generic(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)*, i32)
declare void @llvm.cj.gcwrite.generic(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)*, i32)
