; RUN: split-file %s %t
; RUN: opt -passes=cj-ir-verifier < %t/allow-complete-nonref.ll -disable-output
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-same-size-ref.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=REF,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-partial.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=PARTIAL,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-opaque-source.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=OPAQUE,ABORT

; REF: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; REF-NEXT: call void @llvm.memcpy.p0i8.p1i8.i64
; REF: in function reject_same_size_reference_payload
; PARTIAL: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance.
; PARTIAL-NEXT: call void @llvm.memcpy.p0i8.p1i8.i64
; PARTIAL: in function reject_partial_generic_payload
; OPAQUE: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance.
; OPAQUE-NEXT: call void @llvm.memcpy.p0i8.p1i8.i64
; OPAQUE: in function reject_opaque_source
; ABORT: LLVM ERROR: Broken function found, compilation aborted
; ABORT: error: Aborted

;--- allow-complete-nonref.ll
%OptionRune = type { i1, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }
@OptionRune.ti = external global %TypeInfo, !RelatedType !0

define void @allow_complete_nonreference_generic_payload() gc "cangjie" {
entry:
  %boxed = call i8 addrspace(1)* @llvm.cj.alloca.generic(
      i8* bitcast (%TypeInfo* @OptionRune.ti to i8*), i32 8)
  %boxed.cast = bitcast i8 addrspace(1)* %boxed to i8* addrspace(1)*
  %payload.raw = getelementptr i8*, i8* addrspace(1)* %boxed.cast, i32 1
  %payload = bitcast i8* addrspace(1)* %payload.raw to i8 addrspace(1)*
  %dst = alloca %OptionRune, align 4
  %dst.i8 = bitcast %OptionRune* %dst to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst.i8,
      i8 addrspace(1)* %payload, i64 8, i1 false)
  ret void
}

declare i8 addrspace(1)* @llvm.cj.alloca.generic(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
!0 = !{!"OptionRune"}

;--- reject-same-size-ref.ll
%RefPayload = type { i8 addrspace(1)* }
%Plain = type { i64 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }
@RefPayload.ti = external global %TypeInfo, !RelatedType !0

define void @reject_same_size_reference_payload() gc "cangjie" {
entry:
  %boxed = call i8 addrspace(1)* @llvm.cj.alloca.generic(
      i8* bitcast (%TypeInfo* @RefPayload.ti to i8*), i32 8)
  %boxed.cast = bitcast i8 addrspace(1)* %boxed to i8* addrspace(1)*
  %payload.raw = getelementptr i8*, i8* addrspace(1)* %boxed.cast, i32 1
  %payload = bitcast i8* addrspace(1)* %payload.raw to i8 addrspace(1)*
  %dst = alloca %Plain, align 8
  %dst.i8 = bitcast %Plain* %dst to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst.i8,
      i8 addrspace(1)* %payload, i64 8, i1 false)
  ret void
}

declare i8 addrspace(1)* @llvm.cj.alloca.generic(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
!0 = !{!"RefPayload"}

;--- reject-partial.ll
%OptionRune = type { i1, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }
@OptionRune.ti = external global %TypeInfo, !RelatedType !0

define void @reject_partial_generic_payload() gc "cangjie" {
entry:
  %boxed = call i8 addrspace(1)* @llvm.cj.alloca.generic(
      i8* bitcast (%TypeInfo* @OptionRune.ti to i8*), i32 8)
  %boxed.cast = bitcast i8 addrspace(1)* %boxed to i8* addrspace(1)*
  %payload.raw = getelementptr i8*, i8* addrspace(1)* %boxed.cast, i32 1
  %payload = bitcast i8* addrspace(1)* %payload.raw to i8 addrspace(1)*
  %dst = alloca %OptionRune, align 4
  %dst.i8 = bitcast %OptionRune* %dst to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst.i8,
      i8 addrspace(1)* %payload, i64 4, i1 false)
  ret void
}

declare i8 addrspace(1)* @llvm.cj.alloca.generic(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
!0 = !{!"OptionRune"}

;--- reject-opaque-source.ll
%OptionRune = type { i1, i32 }

define void @reject_opaque_source(i8 addrspace(1)* %src) gc "cangjie" {
entry:
  %dst = alloca %OptionRune, align 4
  %dst.i8 = bitcast %OptionRune* %dst to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst.i8,
      i8 addrspace(1)* %src, i64 8, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
