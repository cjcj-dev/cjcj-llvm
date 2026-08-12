; RUN: opt -passes=cj-barrier-split -S < %s | FileCheck %s --check-prefix=SPLIT
; RUN: not not opt -passes=cj-ir-verifier < %s -disable-output 2>&1 | FileCheck %s --check-prefixes=VERIFY,ABORT

target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"

%Nested = type { [2 x [1 x i8 addrspace(1)*]] }
%Object = type { i8*, %Nested }

declare void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)*, i8 addrspace(1)*, i8*, i64)
declare void @llvm.cj.memset.p0i8(i8*, i8, i64, i1)
declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1 immarg)

; SPLIT-LABEL: define void @split_nested_array
; SPLIT-COUNT-2: call void @llvm.cj.gcwrite.ref
; SPLIT-NOT: call void @llvm.cj.gcwrite.struct
define void @split_nested_array(i8 addrspace(1)* %object, %Nested* %source) gc "cangjie" {
entry:
  %typed = bitcast i8 addrspace(1)* %object to %Object addrspace(1)*
  %field = getelementptr inbounds %Object, %Object addrspace(1)* %typed, i64 0, i32 1
  %dst = bitcast %Nested addrspace(1)* %field to i8 addrspace(1)*
  %src = bitcast %Nested* %source to i8*
  call void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)* %object, i8 addrspace(1)* %dst, i8* %src, i64 16)
  ret void
}

; VERIFY: The WriteBarrier instruction should be used here!
; VERIFY: call void @llvm.memcpy.p1i8.p0i8.i64
define void @reject_raw_nested_array(i8 addrspace(1)* %dst) gc "cangjie" {
entry:
  %source = alloca %Nested, align 8
  %src = bitcast %Nested* %source to i8*
  call void @llvm.cj.memset.p0i8(i8* %src, i8 0, i64 16, i1 false)
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %dst, i8* %src, i64 16, i1 false)
  ret void
}

; ABORT: LLVM ERROR: Broken function found, compilation aborted
