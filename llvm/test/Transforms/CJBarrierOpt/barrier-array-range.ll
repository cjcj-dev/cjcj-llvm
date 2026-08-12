; RUN: opt -passes=cj-barrier-opt -S < %s | FileCheck %s

target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"

%Element = type { i64, i8 addrspace(1)* }
%Outer = type { [2 x %Element] }
%WithPrefix = type { i64, %Outer }

declare void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)*, i8 addrspace(1)*, i8*, i64)

define void @keep_second_element(i8 addrspace(1)* %base, %Outer* %src) gc "cangjie" {
; CHECK-LABEL: @keep_second_element(
; CHECK: call void @llvm.cj.gcwrite.struct.p0i8
entry:
  %second = getelementptr inbounds %Outer, %Outer* %src, i32 0, i32 0, i32 1
  %second.i8 = bitcast %Element* %second to i8*
  call void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)* %base, i8 addrspace(1)* %base, i8* %second.i8, i64 16)
  ret void
}

define void @remove_scalar_prefix(i8 addrspace(1)* %base, %WithPrefix* %src) gc "cangjie" {
; CHECK-LABEL: @remove_scalar_prefix(
; CHECK: call void @llvm.memcpy.p1i8.p0i8.i64
; CHECK-NOT: call void @llvm.cj.gcwrite.struct.p0i8
entry:
  %src.i8 = bitcast %WithPrefix* %src to i8*
  call void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)* %base, i8 addrspace(1)* %base, i8* %src.i8, i64 8)
  ret void
}
