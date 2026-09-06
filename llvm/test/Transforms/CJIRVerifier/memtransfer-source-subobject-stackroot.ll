; RUN: split-file %s %t
; RUN: opt -passes=cj-ir-verifier < %t/allow-nonzero.ll -disable-output
; RUN: opt -passes=cj-ir-verifier < %t/allow-first.ll -disable-output
; RUN: opt -passes=cj-ir-verifier < %t/allow-equal-maps.ll -disable-output
; RUN: opt -passes=cj-ir-verifier < %t/allow-argument.ll -disable-output
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-nonentry-source.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=SRCNONENTRY,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-dynamic-source.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=SRCDYNAMIC,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-erased-dynamic.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=ERASED,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-non-entry.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=NONENTRY,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-dst-argument.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=DSTARG,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-dst-global.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=DSTGLOBAL,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-dst-select.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=DSTSELECT,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-partial.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=PARTIAL,ABORT
; RUN: opt -passes=cj-ir-verifier < %t/reject-dynamic-size.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=DYNSIZE
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-unequal-maps.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=MAPS,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-vector.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=VECTOR,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-heap-dst.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=HEAP,ABORT

; ERASED: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; ERASED: in function reject_erased_dynamic_field_offset
; SRCNONENTRY: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; SRCNONENTRY: in function reject_nonentry_source
; SRCDYNAMIC: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; SRCDYNAMIC: in function reject_dynamic_source
; NONENTRY: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; NONENTRY: in function reject_non_entry_destination
; DSTARG: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; DSTARG: in function reject_destination_argument
; DSTGLOBAL: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; DSTGLOBAL: in function reject_destination_global
; DSTSELECT: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; DSTSELECT: in function reject_selected_destination
; PARTIAL: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; PARTIAL: in function reject_partial_source_subobject
; DYNSIZE: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]
; MAPS: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; MAPS: in function reject_unequal_gc_offset_maps
; VECTOR: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; VECTOR: in function reject_reference_vector_layout
; HEAP: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; HEAP: in function reject_heap_destination
; ABORT: LLVM ERROR: Broken function found, compilation aborted
; ABORT: error: Aborted

;--- allow-nonzero.ll
target datalayout = "e-p:64:64-p1:64:64"
%String = type { i8 addrspace(1)*, i64 }
%OptionString = type { i1, %String }

define void @allow_source_subobject_nonzero_offset_to_entry_root() gc "cangjie" {
entry:
  %dst = alloca %String, align 8
  %src.outer = alloca %OptionString, align 8
  %dst.i8 = bitcast %String* %dst to i8*
  %src.outer.i8 = bitcast %OptionString* %src.outer to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  call void @llvm.cj.memset(i8* %src.outer.i8, i8 0, i64 24, i1 false)
  %src.field = getelementptr inbounds %OptionString, %OptionString* %src.outer, i32 0, i32 1
  %src.i8 = bitcast %String* %src.field to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- allow-first.ll
target datalayout = "e-p:64:64-p1:64:64"
%Payload = type { i8 addrspace(1)*, i64 }
%Outer = type { %Payload, i64 }

define void @allow_source_first_subobject_smaller_than_enclosing() gc "cangjie" {
entry:
  %dst = alloca %Payload, align 8
  %src.outer = alloca %Outer, align 8
  %dst.i8 = bitcast %Payload* %dst to i8*
  %src.outer.i8 = bitcast %Outer* %src.outer to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  call void @llvm.cj.memset(i8* %src.outer.i8, i8 0, i64 24, i1 false)
  %src.field = getelementptr inbounds %Outer, %Outer* %src.outer, i32 0, i32 0
  %src.i8 = bitcast %Payload* %src.field to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- allow-argument.ll
target datalayout = "e-p:64:64-p1:64:64"
%String = type { i8 addrspace(1)*, i64 }
%Token = type { i32, %String, i64 }

define void @allow_typed_argument_subobject(%Token* noalias %src.outer) gc "cangjie" {
entry:
  %dst = alloca %String, align 8
  %dst.i8 = bitcast %String* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  %src.field = getelementptr inbounds %Token, %Token* %src.outer, i32 0, i32 1
  %src.i8 = bitcast %String* %src.field to i8*
  call void @llvm.memmove.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memmove.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-nonentry-source.ll
target datalayout = "e-p:64:64-p1:64:64"
%Payload = type { i8 addrspace(1)*, i64 }
%Outer = type { i64, %Payload }

define void @reject_nonentry_source(i1 %c) gc "cangjie" {
entry:
  %dst = alloca %Payload, align 8
  %dst.i8 = bitcast %Payload* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  br i1 %c, label %body, label %exit
body:
  %src.outer = alloca %Outer, align 8
  %src.outer.i8 = bitcast %Outer* %src.outer to i8*
  call void @llvm.cj.memset(i8* %src.outer.i8, i8 0, i64 24, i1 false)
  %src.field = getelementptr inbounds %Outer, %Outer* %src.outer, i32 0, i32 1
  %src.i8 = bitcast %Payload* %src.field to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  br label %exit
exit:
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-dynamic-source.ll
target datalayout = "e-p:64:64-p1:64:64"
%Payload = type { i8 addrspace(1)*, i64 }
%Outer = type { i64, %Payload }

define void @reject_dynamic_source(i64 %n) gc "cangjie" {
entry:
  %dst = alloca %Payload, align 8
  %dst.i8 = bitcast %Payload* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  br label %body
body:
  %src.outer = alloca %Outer, i64 %n, align 8
  %src.outer.i8 = bitcast %Outer* %src.outer to i8*
  call void @llvm.cj.memset(i8* %src.outer.i8, i8 0, i64 24, i1 false)
  %src.field = getelementptr inbounds %Outer, %Outer* %src.outer, i32 0, i32 1
  %src.i8 = bitcast %Payload* %src.field to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- allow-equal-maps.ll
target datalayout = "e-p:64:64-p1:64:64"
%SrcPayload = type { i8 addrspace(1)*, i64, i8 addrspace(1)*, i64 }
%DstPayload = type { i8 addrspace(1)*, i64, i8 addrspace(1)*, i64 }
%SrcOuter = type { i32, %SrcPayload }

define void @allow_equal_gc_offset_maps_across_distinct_types() gc "cangjie" {
entry:
  %dst = alloca %DstPayload, align 8
  %src.outer = alloca %SrcOuter, align 8
  %dst.i8 = bitcast %DstPayload* %dst to i8*
  %src.outer.i8 = bitcast %SrcOuter* %src.outer to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 32, i1 false)
  call void @llvm.cj.memset(i8* %src.outer.i8, i8 0, i64 40, i1 false)
  %src.field = getelementptr inbounds %SrcOuter, %SrcOuter* %src.outer, i32 0, i32 1
  %src.i8 = bitcast %SrcPayload* %src.field to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 32, i1 false)
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-erased-dynamic.ll
target datalayout = "e-p:64:64-p1:64:64"
%Payload = type { i8 addrspace(1)*, i64 }

define void @reject_erased_dynamic_field_offset(i8* %src.base, i8* %typeinfo) gc "cangjie" {
entry:
  %dst = alloca %Payload, align 8
  %dst.i8 = bitcast %Payload* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  %field.offset = call i64 @llvm.cj.get.field.offset(i8* %typeinfo, i64 1, i32 0)
  %src.raw = getelementptr i8, i8* %src.base, i64 %field.offset
  %src.typed = bitcast i8* %src.raw to %Payload*
  %src.i8 = bitcast %Payload* %src.typed to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare i64 @llvm.cj.get.field.offset(i8*, i64, i32)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-non-entry.ll
target datalayout = "e-p:64:64-p1:64:64"
%Payload = type { i8 addrspace(1)*, i64 }
%Outer = type { i64, %Payload }

define void @reject_non_entry_destination(%Outer* noalias %src.outer) gc "cangjie" {
entry:
  br label %body
body:
  %dst = alloca %Payload, align 8
  %dst.i8 = bitcast %Payload* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  %src.field = getelementptr inbounds %Outer, %Outer* %src.outer, i32 0, i32 1
  %src.i8 = bitcast %Payload* %src.field to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-dst-argument.ll
target datalayout = "e-p:64:64-p1:64:64"
%Payload = type { i8 addrspace(1)*, i64 }
%Outer = type { i64, %Payload }

define void @reject_destination_argument(%Payload* noalias %dst, %Outer* noalias %src.outer) gc "cangjie" {
entry:
  %dst.i8 = bitcast %Payload* %dst to i8*
  %src.field = getelementptr inbounds %Outer, %Outer* %src.outer, i32 0, i32 1
  %src.i8 = bitcast %Payload* %src.field to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-dst-global.ll
target datalayout = "e-p:64:64-p1:64:64"
%Payload = type { i8 addrspace(1)*, i64 }
%Outer = type { i64, %Payload }
@dst = global %Payload zeroinitializer

define void @reject_destination_global(%Outer* noalias %src.outer) gc "cangjie" {
entry:
  %dst.i8 = bitcast %Payload* @dst to i8*
  %src.field = getelementptr inbounds %Outer, %Outer* %src.outer, i32 0, i32 1
  %src.i8 = bitcast %Payload* %src.field to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-dst-select.ll
target datalayout = "e-p:64:64-p1:64:64"
%Payload = type { i8 addrspace(1)*, i64 }
%Outer = type { i64, %Payload }

define void @reject_selected_destination(i1 %pick, %Outer* noalias %src.outer) gc "cangjie" {
entry:
  %dst.a = alloca %Payload, align 8
  %dst.b = alloca %Payload, align 8
  %dst.a.i8 = bitcast %Payload* %dst.a to i8*
  %dst.b.i8 = bitcast %Payload* %dst.b to i8*
  call void @llvm.cj.memset(i8* %dst.a.i8, i8 0, i64 16, i1 false)
  call void @llvm.cj.memset(i8* %dst.b.i8, i8 0, i64 16, i1 false)
  %dst = select i1 %pick, %Payload* %dst.a, %Payload* %dst.b
  %dst.i8 = bitcast %Payload* %dst to i8*
  %src.field = getelementptr inbounds %Outer, %Outer* %src.outer, i32 0, i32 1
  %src.i8 = bitcast %Payload* %src.field to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-partial.ll
target datalayout = "e-p:64:64-p1:64:64"
%Payload = type { i8 addrspace(1)*, i64 }
%Outer = type { i64, %Payload }

define void @reject_partial_source_subobject(%Outer* noalias %src.outer) gc "cangjie" {
entry:
  %dst = alloca %Payload, align 8
  %dst.i8 = bitcast %Payload* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  %src.field = getelementptr inbounds %Outer, %Outer* %src.outer, i32 0, i32 1
  %src.i8 = bitcast %Payload* %src.field to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 8, i1 false)
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-dynamic-size.ll
target datalayout = "e-p:64:64-p1:64:64"
%Payload = type { i8 addrspace(1)*, i64 }
%Outer = type { i64, %Payload }

define void @reject_dynamic_size(%Outer* noalias %src.outer, i64 %size) gc "cangjie" {
entry:
  %dst = alloca %Payload, align 8
  %dst.i8 = bitcast %Payload* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  %src.field = getelementptr inbounds %Outer, %Outer* %src.outer, i32 0, i32 1
  %src.i8 = bitcast %Payload* %src.field to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 %size, i1 false)
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-unequal-maps.ll
target datalayout = "e-p:64:64-p1:64:64"
%Src = type { i8 addrspace(1)*, i64 }
%Dst = type { i64, i8 addrspace(1)* }
%Outer = type { i64, %Src }

define void @reject_unequal_gc_offset_maps(%Outer* noalias %src.outer) gc "cangjie" {
entry:
  %dst = alloca %Dst, align 8
  %dst.i8 = bitcast %Dst* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  %src.field = getelementptr inbounds %Outer, %Outer* %src.outer, i32 0, i32 1
  %src.i8 = bitcast %Src* %src.field to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-vector.ll
target datalayout = "e-p:64:64-p1:64:64"
%VectorPayload = type { <2 x i8 addrspace(1)*> }
%Outer = type { i64, %VectorPayload }

define void @reject_reference_vector_layout() gc "cangjie" {
entry:
  %dst = alloca %VectorPayload, align 16
  %src.outer = alloca %Outer, align 16
  %dst.i8 = bitcast %VectorPayload* %dst to i8*
  %src.outer.i8 = bitcast %Outer* %src.outer to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  call void @llvm.cj.memset(i8* %src.outer.i8, i8 0, i64 32, i1 false)
  %src.field = getelementptr inbounds %Outer, %Outer* %src.outer, i32 0, i32 1
  %src.i8 = bitcast %VectorPayload* %src.field to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-heap-dst.ll
target datalayout = "e-p:64:64-p1:64:64"
%Payload = type { i8 addrspace(1)*, i64 }
%Outer = type { i64, %Payload }

define void @reject_heap_destination(i8 addrspace(1)* %dst, %Outer* noalias %src.outer) gc "cangjie" {
entry:
  %src.field = getelementptr inbounds %Outer, %Outer* %src.outer, i32 0, i32 1
  %src.i8 = bitcast %Payload* %src.field to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %dst, i8* %src.i8, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)
