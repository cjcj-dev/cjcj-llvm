; RUN: split-file %s %t
; RUN: opt -passes=cj-ir-verifier < %t/allow-primitive-layouts.ll -disable-output
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-reference-element.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=REF,ABORT
; RUN: opt -passes=cj-ir-verifier < %t/reject-static-array-source.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=STATIC
; RUN: opt -passes=cj-ir-verifier < %t/reject-untyped-source.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=UNTYPED

; The primitive ArrayLayout rule is type-only: dynamic source/destination
; offsets and a dynamic size do not change whether either E has a GC slot.
;--- allow-primitive-layouts.ll
%ArrayBase = type { i64 }
%ArrayLayout.UInt8 = type { %ArrayBase, [0 x i8] }

define void @allow_primitive_array_layout_transfer(
    i8 addrspace(1)* %dst.base, i8 addrspace(1)* %src.base,
    i64 %dst.offset, i64 %src.offset, i64 %size) gc "cangjie" {
entry:
  %dst.layout = bitcast i8 addrspace(1)* %dst.base to %ArrayLayout.UInt8 addrspace(1)*
  %dst.payload = getelementptr inbounds %ArrayLayout.UInt8, %ArrayLayout.UInt8 addrspace(1)* %dst.layout, i32 0, i32 1
  %dst.bytes = bitcast [0 x i8] addrspace(1)* %dst.payload to i8 addrspace(1)*
  %dst = getelementptr inbounds i8, i8 addrspace(1)* %dst.bytes, i64 %dst.offset
  %src.layout = bitcast i8 addrspace(1)* %src.base to %ArrayLayout.UInt8 addrspace(1)*
  %src.payload = getelementptr inbounds %ArrayLayout.UInt8, %ArrayLayout.UInt8 addrspace(1)* %src.layout, i32 0, i32 1
  %src.bytes = bitcast [0 x i8] addrspace(1)* %src.payload to i8 addrspace(1)*
  %src = getelementptr inbounds i8, i8 addrspace(1)* %src.bytes, i64 %src.offset
  call void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)* %dst,
      i8 addrspace(1)* %src, i64 %size, i1 false)
  ret void
}

declare void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)*, i8 addrspace(1)*, i64, i1)

; One primitive E is not enough: the source E contains an AS1 pointer, so the
; transfer must remain on the existing fail-closed path.
;--- reject-reference-element.ll
%ArrayBase = type { i64 }
%RefElement = type { i8 addrspace(1)* }
%ArrayLayout.UInt8 = type { %ArrayBase, [0 x i8] }
%ArrayLayout.Ref = type { %ArrayBase, [0 x %RefElement] }

; REF: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; REF-NEXT: call void @llvm.memmove.p1i8.p1i8.i64
; REF: in function reject_reference_array_layout_element
define void @reject_reference_array_layout_element(
    i8 addrspace(1)* %dst.base, i8 addrspace(1)* %src.base,
    i64 %size) gc "cangjie" {
entry:
  %dst.layout = bitcast i8 addrspace(1)* %dst.base to %ArrayLayout.UInt8 addrspace(1)*
  %dst.payload = getelementptr inbounds %ArrayLayout.UInt8, %ArrayLayout.UInt8 addrspace(1)* %dst.layout, i32 0, i32 1
  %dst = bitcast [0 x i8] addrspace(1)* %dst.payload to i8 addrspace(1)*
  %src.layout = bitcast i8 addrspace(1)* %src.base to %ArrayLayout.Ref addrspace(1)*
  %src.payload = getelementptr inbounds %ArrayLayout.Ref, %ArrayLayout.Ref addrspace(1)* %src.layout, i32 0, i32 1
  %src = bitcast [0 x %RefElement] addrspace(1)* %src.payload to i8 addrspace(1)*
  call void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)* %dst,
      i8 addrspace(1)* %src, i64 %size, i1 false)
  ret void
}

declare void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)*, i8 addrspace(1)*, i64, i1)

; A static [N x i8] source is not an ArrayLayout payload chain, even though
; its bytes contain no managed pointer.
;--- reject-static-array-source.ll
%ArrayBase = type { i64 }
%ArrayLayout.UInt8 = type { %ArrayBase, [0 x i8] }

@bytes = internal constant [16 x i8] zeroinitializer

; STATIC: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]
; STATIC-NEXT: call void @llvm.memmove.p1i8.p1i8.i64
; STATIC: in function reject_static_array_source
define void @reject_static_array_source(i8 addrspace(1)* %dst.base) gc "cangjie" {
entry:
  %dst.layout = bitcast i8 addrspace(1)* %dst.base to %ArrayLayout.UInt8 addrspace(1)*
  %dst.payload = getelementptr inbounds %ArrayLayout.UInt8, %ArrayLayout.UInt8 addrspace(1)* %dst.layout, i32 0, i32 1
  %dst = bitcast [0 x i8] addrspace(1)* %dst.payload to i8 addrspace(1)*
  call void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)* %dst,
      i8 addrspace(1)* addrspacecast (i8* getelementptr inbounds ([16 x i8], [16 x i8]* @bytes, i32 0, i32 0) to i8 addrspace(1)*),
      i64 16, i1 false)
  ret void
}

declare void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)*, i8 addrspace(1)*, i64, i1)

; The destination has a unique primitive payload selector, but the source has
; no ArrayLayout type.  One typed endpoint never admits the transfer.
;--- reject-untyped-source.ll
%ArrayBase = type { i64 }
%ArrayLayout.UInt8 = type { %ArrayBase, [0 x i8] }

; UNTYPED: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]
; UNTYPED-NEXT: call void @llvm.memmove.p1i8.p1i8.i64
; UNTYPED: in function reject_untyped_source
define void @reject_untyped_source(
    i8 addrspace(1)* %dst.base, i8 addrspace(1)* %src,
    i64 %size) gc "cangjie" {
entry:
  %dst.layout = bitcast i8 addrspace(1)* %dst.base to %ArrayLayout.UInt8 addrspace(1)*
  %dst.payload = getelementptr inbounds %ArrayLayout.UInt8, %ArrayLayout.UInt8 addrspace(1)* %dst.layout, i32 0, i32 1
  %dst = bitcast [0 x i8] addrspace(1)* %dst.payload to i8 addrspace(1)*
  call void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)* %dst,
      i8 addrspace(1)* %src, i64 %size, i1 false)
  ret void
}

declare void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)*, i8 addrspace(1)*, i64, i1)

; ABORT: LLVM ERROR: Broken function found, compilation aborted
; ABORT: error: Aborted
