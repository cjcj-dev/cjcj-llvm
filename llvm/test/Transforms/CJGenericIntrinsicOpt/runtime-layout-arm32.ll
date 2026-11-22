; RUN: opt -passes=cj-generic-intrinsic-opt -S < %s | FileCheck %s
; ARM32: the native object header is sizeof(TypeInfo *) + 4 = 8 bytes even
; though pointers are 4 bytes; only the Wasm runtime uses the compact 4-byte
; header. The generic copies must address the payload at +8 with align 8.
target datalayout = "e-m:e-p:32:32-Fi8-i64:64-v128:64:128-a:0:32-n32-S64"
target triple = "armv7a-unknown-linux-gnueabihf"
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, i8**, i8*, i8* }

; CHECK-LABEL: define void @assign(
; CHECK: getelementptr %TypeInfo, %TypeInfo* %{{.*}}, i32 0, i32 4
; CHECK: load i32, i32* %{{.*}}
; CHECK: getelementptr i8, i8 addrspace(1)* %dst, i32 8
; CHECK: getelementptr i8, i8 addrspace(1)* %src, i32 8
; CHECK: call void @llvm.memcpy.{{.*}} align 8 {{.*}} align 8
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
; CHECK: call void @llvm.memcpy.{{.*}} align 8 {{.*}} align 8
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
; CHECK: call void @llvm.memcpy.{{.*}} align 8 {{.*}} align 8
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
