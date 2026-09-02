; RUN: split-file %s %t
; RUN: opt -passes=cj-ir-verifier < %t/allow-complete-typed-destination.ll -disable-output
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-untyped-as0-destination.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=UNTYPED,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-as0-reference-slot.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=DSTREF,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-multi-index-source.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=MULTI,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-selected-base-source.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=SELECT,ABORT
; RUN: opt -passes=cj-ir-verifier < %t/allow-classified-allocation-source.ll -disable-output

; Source bytes must independently prove NoReference, and an AS0 destination
; is admitted only when it is a complete typed object with no managed fields.
; UNTYPED: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance.
; UNTYPED-NEXT: call void @llvm.memcpy.p0i8.p1i8.i64
; UNTYPED: in function reject_untyped_as0_destination
; DSTREF: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; DSTREF-NEXT: call void @llvm.memcpy.p0i8.p1i8.i64
; DSTREF: in function reject_as0_alloca_reference_slot
; MULTI: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance.
; MULTI-NEXT: call void @llvm.memcpy.p0i8.p1i8.i64
; MULTI: in function reject_typed_source_with_preceding_index
; SELECT: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance.
; SELECT-NEXT: call void @llvm.memcpy.p0i8.p1i8.i64
; SELECT: in function reject_typed_source_with_selected_base
; ABORT: LLVM ERROR: Broken function found, compilation aborted
; ABORT: error: Aborted

;--- allow-complete-typed-destination.ll
%Plain24 = type { i64, i64, i32, i32 }

define void @allow_complete_typed_destination(i8 addrspace(1)* %object) gc "cangjie" {
entry:
  %carrier = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.raw = getelementptr i8*, i8* addrspace(1)* %carrier, i32 1
  %payload.typed = bitcast i8* addrspace(1)* %payload.raw to %Plain24 addrspace(1)*
  %src = bitcast %Plain24 addrspace(1)* %payload.typed to i8 addrspace(1)*
  %dst.object = alloca %Plain24, align 8
  %dst = bitcast %Plain24* %dst.object to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst, i8 addrspace(1)* %src,
                                       i64 24, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)

;--- allow-classified-allocation-source.ll
%Plain8 = type { i64 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }
@Plain8.ti = external global %TypeInfo, !RelatedType !0

define void @allow_typed_source_from_classified_allocation() gc "cangjie" {
entry:
  %object = call i8 addrspace(1)* @llvm.cj.malloc.object(
      i8* bitcast (%TypeInfo* @Plain8.ti to i8*), i32 8)
  %carrier = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.raw = getelementptr i8*, i8* addrspace(1)* %carrier, i32 1
  %payload.typed = bitcast i8* addrspace(1)* %payload.raw to %Plain8 addrspace(1)*
  %src = bitcast %Plain8 addrspace(1)* %payload.typed to i8 addrspace(1)*
  %dst.object = alloca %Plain8, align 8
  %dst = bitcast %Plain8* %dst.object to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst, i8 addrspace(1)* %src,
                                       i64 8, i1 false)
  ret void
}

declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
!0 = !{!"Plain8"}

;--- reject-untyped-as0-destination.ll
%Plain24 = type { i64, i64, i32, i32 }

define void @reject_untyped_as0_destination(i8* %dst,
                                             i8 addrspace(1)* %object) gc "cangjie" {
entry:
  %carrier = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.raw = getelementptr i8*, i8* addrspace(1)* %carrier, i32 1
  %payload.typed = bitcast i8* addrspace(1)* %payload.raw to %Plain24 addrspace(1)*
  %src = bitcast %Plain24 addrspace(1)* %payload.typed to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst, i8 addrspace(1)* %src,
                                       i64 24, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)

;--- reject-as0-reference-slot.ll
%RefPayload = type { i8 addrspace(1)* }
@zeros = internal constant [8 x i8] zeroinitializer

define void @reject_as0_alloca_reference_slot() gc "cangjie" {
entry:
  %dst.object = alloca %RefPayload, align 8
  %dst = bitcast %RefPayload* %dst.object to i8*
  call void @llvm.cj.memset(i8* %dst, i8 0, i64 8, i1 false)
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst,
      i8 addrspace(1)* addrspacecast (i8* getelementptr inbounds
          ([8 x i8], [8 x i8]* @zeros, i32 0, i32 0) to i8 addrspace(1)*),
      i64 8, i1 false)
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)

;--- reject-multi-index-source.ll
%Plain8 = type { i64 }

define void @reject_typed_source_with_preceding_index(
    i8 addrspace(1)* %object) gc "cangjie" {
entry:
  %container = bitcast i8 addrspace(1)* %object to [2 x i8*] addrspace(1)*
  %payload.raw = getelementptr [2 x i8*], [2 x i8*] addrspace(1)* %container,
                               i32 0, i32 1
  %payload.typed = bitcast i8* addrspace(1)* %payload.raw to %Plain8 addrspace(1)*
  %src = bitcast %Plain8 addrspace(1)* %payload.typed to i8 addrspace(1)*
  %dst.object = alloca %Plain8, align 8
  %dst = bitcast %Plain8* %dst.object to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst, i8 addrspace(1)* %src,
                                       i64 8, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)

;--- reject-selected-base-source.ll
%Plain8 = type { i64 }

define void @reject_typed_source_with_selected_base(
    i1 %pick, i8 addrspace(1)* %a, i8 addrspace(1)* %b) gc "cangjie" {
entry:
  %object = select i1 %pick, i8 addrspace(1)* %a, i8 addrspace(1)* %b
  %carrier = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.raw = getelementptr i8*, i8* addrspace(1)* %carrier, i32 1
  %payload.typed = bitcast i8* addrspace(1)* %payload.raw to %Plain8 addrspace(1)*
  %src = bitcast %Plain8 addrspace(1)* %payload.typed to i8 addrspace(1)*
  %dst.object = alloca %Plain8, align 8
  %dst = bitcast %Plain8* %dst.object to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst, i8 addrspace(1)* %src,
                                       i64 8, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
