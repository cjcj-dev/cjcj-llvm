; RUN: split-file %s %t
; RUN: opt -passes=cj-ir-verifier < %t/typed-nonref.ll -disable-output
; RUN: opt -passes=cj-ir-verifier < %t/typed-provenance.ll -disable-output
; RUN: opt -passes=cj-ir-verifier < %t/opaque-no-provenance.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=OPAQUE
; RUN: opt -passes=cj-ir-verifier < %t/dynamic-size.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=DYNAMIC

; OPAQUE: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]
; OPAQUE-NEXT: call void @llvm.memmove.p0i8.p0i8.i64
; OPAQUE: in function reject_opaque_memmove
; DYNAMIC: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]
; DYNAMIC-NEXT: call void @llvm.memcpy.p0i8.p0i8.i64
; DYNAMIC: in function reject_dynamic_plain_memcpy
; ABORT: LLVM ERROR: Broken function found, compilation aborted
; ABORT: error: Aborted

;--- typed-nonref.ll
%plain = type { i64, i64 }
%mixed = type { i64, i8 addrspace(1)* }

define void @allow_plain_memcpy() gc "cangjie" {
entry:
  %dst = alloca %plain, align 8
  %src = alloca %plain, align 8
  %dst.i8 = bitcast %plain* %dst to i8*
  %src.i8 = bitcast %plain* %src to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8,
                                       i64 16, i1 false)
  ret void
}

; A statically bounded span ending before the reference field remains legal.
define void @allow_nonreference_prefix_of_mixed_payload() gc "cangjie" {
entry:
  %dst = alloca %mixed, align 8
  %src = alloca %mixed, align 8
  %dst.i8 = bitcast %mixed* %dst to i8*
  %src.i8 = bitcast %mixed* %src to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  call void @llvm.cj.memset(i8* %src.i8, i8 0, i64 16, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8,
                                       i64 8, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
declare void @llvm.memmove.p0i8.p0i8.i64(i8*, i8*, i64, i1)
declare void @llvm.cj.memset(i8*, i8, i64, i1)

;--- typed-provenance.ll
%plain = type { i64, i64 }

; The same 16-byte memmove rejected in the opaque section is legal after
; typed provenance establishes a reference-free layout.
define void @allow_memmove_with_typed_provenance() gc "cangjie" {
entry:
  %dst = alloca %plain, align 8
  %src = alloca %plain, align 8
  %dst.i8 = bitcast %plain* %dst to i8*
  %src.i8 = bitcast %plain* %src to i8*
  call void @llvm.memmove.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8,
                                        i64 16, i1 false)
  ret void
}

declare void @llvm.memmove.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- opaque-no-provenance.ll
define void @reject_opaque_memmove(i8* %dst, i8* %src) gc "cangjie" {
entry:
  call void @llvm.memmove.p0i8.p0i8.i64(i8* %dst, i8* %src,
                                        i64 16, i1 false)
  ret void
}

declare void @llvm.memmove.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- dynamic-size.ll
%plain = type { i64, i64 }

define void @reject_dynamic_plain_memcpy(i64 %size) gc "cangjie" {
entry:
  %dst = alloca %plain, align 8
  %src = alloca %plain, align 8
  %dst.i8 = bitcast %plain* %dst to i8*
  %src.i8 = bitcast %plain* %src to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8,
                                       i64 %size, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
