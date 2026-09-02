; RUN: split-file %s %t
; RUN: opt -passes=cj-ir-verifier < %t/allow.ll -disable-output
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-no-noalias.ll -disable-output 2>&1 | FileCheck %s --check-prefixes=NOALIAS,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-sret.ll -disable-output 2>&1 | FileCheck %s --check-prefixes=SRET,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-byval.ll -disable-output 2>&1 | FileCheck %s --check-prefixes=BYVAL,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-no-gc.ll -disable-output 2>&1 | FileCheck %s --check-prefixes=NOGC,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-boundaries.ll -disable-output 2>&1 | FileCheck %s --check-prefixes=BOUNDARY,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-as1.ll -disable-output 2>&1 | FileCheck %s --check-prefixes=AS1,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-array-descent.ll -disable-output 2>&1 | FileCheck %s --check-prefixes=ARRAY,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-layout.ll -disable-output 2>&1 | FileCheck %s --check-prefixes=LAYOUT,ABORT

; NOALIAS: in function reject_source_without_noalias
; SRET: in function reject_sret_source
; BYVAL: in function reject_byval_source
; NOGC: in function reject_source_outside_cangjie_gc
; BOUNDARY-DAG: in function reject_cfunc_source
; BOUNDARY-DAG: in function reject_c2cj_source
; BOUNDARY-DAG: in function reject_cj2c_source
; BOUNDARY-DAG: in function reject_pkg_c_wrapper_source
; BOUNDARY-DAG: in function reject_cjstub_source
; AS1: in function reject_as1_source
; ARRAY: in function reject_array_descent
; LAYOUT: in function reject_argument_layout_mismatch
; ABORT: LLVM ERROR: Broken function found, compilation aborted
; ABORT: error: Aborted

;--- allow.ll
target datalayout = "e-p:64:64-p1:64:64"
%Payload = type { i8 addrspace(1)*, i64 }
%Outer = type { i32, %Payload }
%Nested = type { i8, %Outer }

define void @allow_ordinary_argument(%Outer* noalias nocapture readonly %arg) gc "cangjie" {
entry:
  %dst = alloca %Payload, align 8
  %dst.i8 = bitcast %Payload* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  %src = getelementptr inbounds %Outer, %Outer* %arg, i32 0, i32 1
  %src.i8 = bitcast %Payload* %src to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}

define void @allow_immutable_this(%Outer* noalias nocapture readonly %this) gc "cangjie" {
entry:
  %dst = alloca %Payload, align 8
  %dst.i8 = bitcast %Payload* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  %src = getelementptr inbounds %Outer, %Outer* %this, i32 0, i32 1
  %src.i8 = bitcast %Payload* %src to i8*
  call void @llvm.memmove.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}

; Tuple/enum value ABI arguments need no readonly or nocapture attribute.
define void @allow_only_noalias(%Outer* noalias %tuple) gc "cangjie" {
entry:
  %dst = alloca %Payload, align 8
  %dst.i8 = bitcast %Payload* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  %src = getelementptr inbounds %Outer, %Outer* %tuple, i32 0, i32 1
  %src.i8 = bitcast %Payload* %src to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}

; A multi-frame forwarding chain has this same callee-visible nested GEP shape.
define void @allow_nested_forwarding(%Nested* noalias %forwarded) gc "cangjie" {
entry:
  %dst = alloca %Payload, align 8
  %dst.i8 = bitcast %Payload* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  %src = getelementptr inbounds %Nested, %Nested* %forwarded, i32 0, i32 1, i32 1
  %src.i8 = bitcast %Payload* %src to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
declare void @llvm.memmove.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-no-noalias.ll
target datalayout = "e-p:64:64-p1:64:64"
%Payload = type { i8 addrspace(1)*, i64 }
%Outer = type { i32, %Payload }
define void @reject_source_without_noalias(%Outer* %arg) gc "cangjie" {
entry:
  %dst = alloca %Payload
  %dst.i8 = bitcast %Payload* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  %src = getelementptr %Outer, %Outer* %arg, i32 0, i32 1
  %src.i8 = bitcast %Payload* %src to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}
declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-sret.ll
target datalayout = "e-p:64:64-p1:64:64"
%Payload = type { i8 addrspace(1)*, i64 }
%Outer = type { i32, %Payload }
define void @reject_sret_source(%Outer* noalias sret(%Outer) %arg) gc "cangjie" {
entry:
  %dst = alloca %Payload
  %dst.i8 = bitcast %Payload* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  %src = getelementptr %Outer, %Outer* %arg, i32 0, i32 1
  %src.i8 = bitcast %Payload* %src to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}
declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-byval.ll
target datalayout = "e-p:64:64-p1:64:64"
%Payload = type { i8 addrspace(1)*, i64 }
%Outer = type { i32, %Payload }
define void @reject_byval_source(%Outer* noalias byval(%Outer) %arg) gc "cangjie" {
entry:
  %dst = alloca %Payload
  %dst.i8 = bitcast %Payload* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  %src = getelementptr %Outer, %Outer* %arg, i32 0, i32 1
  %src.i8 = bitcast %Payload* %src to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}
declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-no-gc.ll
target datalayout = "e-p:64:64-p1:64:64"
%Payload = type { i8 addrspace(1)*, i64 }
%Outer = type { i32, %Payload }
define void @reject_source_outside_cangjie_gc(%Outer* noalias %arg) {
entry:
  %dst = alloca %Payload
  %dst.i8 = bitcast %Payload* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  %src = getelementptr %Outer, %Outer* %arg, i32 0, i32 1
  %src.i8 = bitcast %Payload* %src to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}
declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-boundaries.ll
target datalayout = "e-p:64:64-p1:64:64"
%Payload = type { i8 addrspace(1)*, i64 }
%Outer = type { i32, %Payload }

define void @reject_cfunc_source(%Outer* noalias %arg) #0 gc "cangjie" {
entry:
  %dst = alloca %Payload
  %dst.i8 = bitcast %Payload* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  %src = getelementptr %Outer, %Outer* %arg, i32 0, i32 1
  %src.i8 = bitcast %Payload* %src to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}
define void @reject_c2cj_source(%Outer* noalias %arg) #1 gc "cangjie" {
entry:
  %dst = alloca %Payload
  %dst.i8 = bitcast %Payload* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  %src = getelementptr %Outer, %Outer* %arg, i32 0, i32 1
  %src.i8 = bitcast %Payload* %src to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}
define void @reject_cj2c_source(%Outer* noalias %arg) #2 gc "cangjie" {
entry:
  %dst = alloca %Payload
  %dst.i8 = bitcast %Payload* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  %src = getelementptr %Outer, %Outer* %arg, i32 0, i32 1
  %src.i8 = bitcast %Payload* %src to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}
define void @reject_pkg_c_wrapper_source(%Outer* noalias %arg) #3 gc "cangjie" {
entry:
  %dst = alloca %Payload
  %dst.i8 = bitcast %Payload* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  %src = getelementptr %Outer, %Outer* %arg, i32 0, i32 1
  %src.i8 = bitcast %Payload* %src to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}
define void @reject_cjstub_source(%Outer* noalias %arg) #4 gc "cangjie" {
entry:
  %dst = alloca %Payload
  %dst.i8 = bitcast %Payload* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  %src = getelementptr %Outer, %Outer* %arg, i32 0, i32 1
  %src.i8 = bitcast %Payload* %src to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}
declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
attributes #0 = { "cfunc" }
attributes #1 = { "c2cj" }
attributes #2 = { "cj2c" }
attributes #3 = { "pkg_c_wrapper" }
attributes #4 = { "cjstub" }

;--- reject-as1.ll
target datalayout = "e-p:64:64-p1:64:64"
%Payload = type { i8 addrspace(1)*, i64 }
%Outer = type { i32, %Payload }
define void @reject_as1_source(i8 addrspace(1)* noalias %base) gc "cangjie" {
entry:
  %dst = alloca %Payload
  %dst.i8 = bitcast %Payload* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  %arg = addrspacecast i8 addrspace(1)* %base to %Outer*
  %src = getelementptr %Outer, %Outer* %arg, i32 0, i32 1
  %src.i8 = bitcast %Payload* %src to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}
declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-array-descent.ll
target datalayout = "e-p:64:64-p1:64:64"
%Payload = type { i8 addrspace(1)*, i64 }
%Outer = type { [2 x %Payload] }
define void @reject_array_descent(%Outer* noalias %arg) gc "cangjie" {
entry:
  %dst = alloca %Payload
  %dst.i8 = bitcast %Payload* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  %src = getelementptr %Outer, %Outer* %arg, i32 0, i32 0, i32 1
  %src.i8 = bitcast %Payload* %src to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}
declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-layout.ll
target datalayout = "e-p:64:64-p1:64:64"
%Dst = type { i8 addrspace(1)*, i64, i8 addrspace(1)*, i64 }
%Src = type { i8 addrspace(1)*, i8 addrspace(1)*, i64, i64 }
%Outer = type { i32, %Src }
define void @reject_argument_layout_mismatch(%Outer* noalias %arg) gc "cangjie" {
entry:
  %dst = alloca %Dst
  %dst.i8 = bitcast %Dst* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 32, i1 false)
  %src = getelementptr %Outer, %Outer* %arg, i32 0, i32 1
  %src.i8 = bitcast %Src* %src to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 32, i1 false)
  ret void
}
declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
