; RUN: opt -passes=cj-generic-intrinsic-opt -S < %s | FileCheck %s
; wasm32: the object header is the 4-byte TypeInfo pointer, so the generic
; copies address the payload at +4 (CJW_OBJECT_HEADER_SIZE), not the 64-bit +8,
; and the payload is only 4-byte aligned.
target datalayout = "e-m:e-p:32:32-p10:8:8-p20:8:8-i64:64-n32:64-S128-ni:1:10:20"
target triple = "wasm32-unknown-wasi"
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, i8**, i8*, i8* }

; CHECK-LABEL: define void @assign(
; CHECK: getelementptr %TypeInfo, %TypeInfo* %{{.*}}, i32 0, i32 4
; CHECK: load i32, i32* %{{.*}}
; CHECK: getelementptr i8, i8 addrspace(1)* %dst, i32 4
; CHECK: getelementptr i8, i8 addrspace(1)* %src, i32 4
; CHECK: call void @llvm.memcpy.{{.*}} align 4 {{.*}} align 4
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
; CHECK: getelementptr i8, i8 addrspace(1)* %dst, i32 4
; CHECK: call void @llvm.memcpy.{{.*}} align 4 {{.*}} align 4
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
; CHECK: getelementptr i8, i8 addrspace(1)* %src, i32 4
; CHECK: call void @llvm.memcpy.{{.*}} align 4 {{.*}} align 4
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
