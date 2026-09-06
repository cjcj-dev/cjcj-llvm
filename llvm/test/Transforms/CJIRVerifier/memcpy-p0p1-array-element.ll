; RUN: split-file %s %t
; RUN: opt -passes=cj-ir-verifier < %t/allow-formattype-element.ll -disable-output
; RUN: opt '-passes=default<O0>' --cangjie-pipeline -disable-output < %t/allow-formattype-element.ll
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-ref-element.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=REF,ABORT
; RUN: not not opt '-passes=default<O0>' --cangjie-pipeline -disable-output < %t/reject-ref-element.ll 2>&1 | FileCheck %s -check-prefixes=REF,ABORT
; RUN: opt -passes=cj-ir-verifier < %t/reject-size-mismatch.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=SIZE
; RUN: opt '-passes=default<O0>' --cangjie-pipeline -disable-output < %t/reject-size-mismatch.ll 2>&1 | FileCheck %s -check-prefixes=SIZE
; RUN: opt -passes=cj-ir-verifier < %t/reject-unnamed-i8-array.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=BARE
; RUN: opt '-passes=default<O0>' --cangjie-pipeline -disable-output < %t/reject-unnamed-i8-array.ll 2>&1 | FileCheck %s -check-prefixes=BARE
; RUN: opt -passes=cj-ir-verifier < %t/reject-heap-dest.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=HEAP
; RUN: opt '-passes=default<O0>' --cangjie-pipeline -disable-output < %t/reject-heap-dest.ll 2>&1 | FileCheck %s -check-prefixes=HEAP

;--- allow-formattype-element.ll
%ArrayBase = type { i8 addrspace(1)*, i64 }
%"ArrayLayout.std.time:FormatType" = type { %ArrayBase, [0 x [12 x i8]] }

define void @allow_formattype_element_to_stack(
    i8 addrspace(1)* %src.base, i64 %idx) gc "cangjie" {
entry:
  %dst = alloca [12 x i8], align 1
  %layout = bitcast i8 addrspace(1)* %src.base to %"ArrayLayout.std.time:FormatType" addrspace(1)*
  %elt = getelementptr inbounds %"ArrayLayout.std.time:FormatType", %"ArrayLayout.std.time:FormatType" addrspace(1)* %layout, i32 0, i32 1, i64 %idx
  %dst.i8 = bitcast [12 x i8]* %dst to i8*
  %src.i8 = bitcast [12 x i8] addrspace(1)* %elt to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst.i8, i8 addrspace(1)* %src.i8, i64 12, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)

;--- reject-ref-element.ll
%ArrayBase = type { i8 addrspace(1)*, i64 }
%ArrayLayout.refArray = type { %ArrayBase, [0 x i8 addrspace(1)*] }

; REF: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; REF-NEXT: call void @llvm.memcpy.p0i8.p1i8.i64
; REF: in function reject_ref_array_element_to_stack
define void @reject_ref_array_element_to_stack(
    i8 addrspace(1)* %src.base, i64 %idx) gc "cangjie" {
entry:
  %dst = alloca i8 addrspace(1)*, align 8
  %layout = bitcast i8 addrspace(1)* %src.base to %ArrayLayout.refArray addrspace(1)*
  %elt = getelementptr inbounds %ArrayLayout.refArray, %ArrayLayout.refArray addrspace(1)* %layout, i32 0, i32 1, i64 %idx
  %dst.i8 = bitcast i8 addrspace(1)** %dst to i8*
  %src.i8 = bitcast i8 addrspace(1)* addrspace(1)* %elt to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst.i8, i8 addrspace(1)* %src.i8, i64 8, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)

;--- reject-size-mismatch.ll
%ArrayBase = type { i8 addrspace(1)*, i64 }
%"ArrayLayout.std.time:FormatType" = type { %ArrayBase, [0 x [12 x i8]] }

; SIZE: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]
; SIZE-NEXT: call void @llvm.memcpy.p0i8.p1i8.i64
define void @reject_element_size_mismatch(
    i8 addrspace(1)* %src.base, i64 %idx) gc "cangjie" {
entry:
  %dst = alloca [8 x i8], align 1
  %layout = bitcast i8 addrspace(1)* %src.base to %"ArrayLayout.std.time:FormatType" addrspace(1)*
  %elt = getelementptr inbounds %"ArrayLayout.std.time:FormatType", %"ArrayLayout.std.time:FormatType" addrspace(1)* %layout, i32 0, i32 1, i64 %idx
  %dst.i8 = bitcast [8 x i8]* %dst to i8*
  %src.i8 = bitcast [12 x i8] addrspace(1)* %elt to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst.i8, i8 addrspace(1)* %src.i8, i64 8, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)

;--- reject-unnamed-i8-array.ll
; BARE: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]
; BARE-NEXT: call void @llvm.memcpy.p0i8.p1i8.i64
define void @reject_unnamed_i8_array(
    i8 addrspace(1)* %src.base, i64 %idx) gc "cangjie" {
entry:
  %dst = alloca [12 x i8], align 1
  %src = bitcast i8 addrspace(1)* %src.base to [0 x [12 x i8]] addrspace(1)*
  %elt = getelementptr inbounds [0 x [12 x i8]], [0 x [12 x i8]] addrspace(1)* %src, i32 0, i64 %idx
  %dst.i8 = bitcast [12 x i8]* %dst to i8*
  %src.i8 = bitcast [12 x i8] addrspace(1)* %elt to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst.i8, i8 addrspace(1)* %src.i8, i64 12, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)

;--- reject-heap-dest.ll
%ArrayBase = type { i8 addrspace(1)*, i64 }
%"ArrayLayout.std.time:FormatType" = type { %ArrayBase, [0 x [12 x i8]] }

; HEAP: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]
; HEAP-NEXT: call void @llvm.memcpy.p1i8.p1i8.i64
define void @reject_heap_dest(
    i8 addrspace(1)* %src.base, i8 addrspace(1)* %dst.base, i64 %idx) gc "cangjie" {
entry:
  %layout = bitcast i8 addrspace(1)* %src.base to %"ArrayLayout.std.time:FormatType" addrspace(1)*
  %elt = getelementptr inbounds %"ArrayLayout.std.time:FormatType", %"ArrayLayout.std.time:FormatType" addrspace(1)* %layout, i32 0, i32 1, i64 %idx
  %src.i8 = bitcast [12 x i8] addrspace(1)* %elt to i8 addrspace(1)*
  call void @llvm.memcpy.p1i8.p1i8.i64(i8 addrspace(1)* %dst.base, i8 addrspace(1)* %src.i8, i64 12, i1 false)
  ret void
}

declare void @llvm.memcpy.p1i8.p1i8.i64(i8 addrspace(1)*, i8 addrspace(1)*, i64, i1)

; ABORT: LLVM ERROR: Broken function found, compilation aborted
; ABORT: error: Aborted
