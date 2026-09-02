; RUN: split-file %s %t
; RUN: opt -passes=cj-ir-verifier < %t/struct-roots.ll -disable-output
; RUN: opt -passes=cj-ir-verifier < %t/argument-source.ll -disable-output
; RUN: opt -passes=cj-ir-verifier < %t/constant-global-source.ll -disable-output
; RUN: opt -passes=cj-ir-verifier < %t/primitive-array-element.ll -disable-output
; RUN: not not opt -passes=cj-ir-verifier < %t/array-destination.ll -disable-output 2>&1 | FileCheck %s --check-prefixes=ARRAYDST,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %t/array-source.ll -disable-output 2>&1 | FileCheck %s --check-prefixes=ARRAYSRC,ABORT

; ARRAYDST: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; ARRAYDST: in function reject_array_element_destination
; ARRAYSRC: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; ARRAYSRC: in function reject_array_element_source
; ABORT: LLVM ERROR: Broken function found, compilation aborted
; ABORT: error: Aborted

;--- struct-roots.ll
target datalayout = "e-p:64:64-p1:64:64"
%S = type { i8 addrspace(1)*, i64 }
define void @allow_registered_struct_roots() gc "cangjie" {
entry:
  %dst = alloca %S, align 8
  %src = alloca %S, align 8
  %dst.i8 = bitcast %S* %dst to i8*
  %src.i8 = bitcast %S* %src to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  call void @llvm.cj.memset(i8* %src.i8, i8 0, i64 16, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}
declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- argument-source.ll
target datalayout = "e-p:64:64-p1:64:64"
%S = type { i8 addrspace(1)*, i64 }
define void @allow_whole_abi_argument_source(%S* noalias %src) gc "cangjie" {
entry:
  %dst = alloca %S, align 8
  %dst.i8 = bitcast %S* %dst to i8*
  %src.i8 = bitcast %S* %src to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}
declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- constant-global-source.ll
target datalayout = "e-p:64:64-p1:64:64"
%S = type { i8 addrspace(1)*, i64 }
@source = internal constant %S { i8 addrspace(1)* null, i64 0 }
define void @allow_typed_constant_global_source() gc "cangjie" {
entry:
  %dst = alloca %S, align 8
  %dst.i8 = bitcast %S* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* bitcast (%S* @source to i8*), i64 16, i1 false)
  ret void
}
declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- primitive-array-element.ll
target datalayout = "e-p:64:64-p1:64:64"
%P = type { i64, i32 }
define void @allow_primitive_array_element() {
entry:
  %dst = alloca %P, align 8
  %src.array = alloca [1 x %P], align 8
  %src = getelementptr inbounds [1 x %P], [1 x %P]* %src.array, i32 0, i32 0
  %dst.i8 = bitcast %P* %dst to i8*
  %src.i8 = bitcast %P* %src to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- array-destination.ll
target datalayout = "e-p:64:64-p1:64:64"
%S = type { i8 addrspace(1)*, i64 }
define void @reject_array_element_destination(%S* noalias %src) gc "cangjie" {
entry:
  %dst.array = alloca [1 x %S], align 8
  %dst = getelementptr inbounds [1 x %S], [1 x %S]* %dst.array, i32 0, i32 0
  %dst.i8 = bitcast %S* %dst to i8*
  %src.i8 = bitcast %S* %src to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- array-source.ll
target datalayout = "e-p:64:64-p1:64:64"
%S = type { i8 addrspace(1)*, i64 }
define void @reject_array_element_source() gc "cangjie" {
entry:
  %dst = alloca %S, align 8
  %src.array = alloca [1 x %S], align 8
  %src = getelementptr inbounds [1 x %S], [1 x %S]* %src.array, i32 0, i32 0
  %dst.i8 = bitcast %S* %dst to i8*
  %src.i8 = bitcast %S* %src to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}
declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
