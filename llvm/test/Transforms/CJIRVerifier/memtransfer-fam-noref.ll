; RUN: split-file %s %t
; RUN: opt -passes=cj-ir-verifier < %t/allow-as1-parent.ll -disable-output
; RUN: opt -passes=cj-ir-verifier < %t/allow-p0-subobject.ll -disable-output
; RUN: opt -passes=cj-ir-verifier < %t/allow-dynamic-native-bytes.ll -disable-output
; RUN: opt -passes=cj-ir-verifier < %t/allow-stack-to-heap.ll -disable-output
; RUN: opt -passes=cj-ir-verifier < %t/allow-different-types.ll -disable-output
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-reference.ll -disable-output 2>&1 | FileCheck %s --check-prefix=REF
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-as1-bare-dst.ll -disable-output 2>&1 | FileCheck %s --check-prefix=BARE
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-dynamic-size.ll -disable-output 2>&1 | FileCheck %s --check-prefix=DYNAMIC
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-dynamic-field.ll -disable-output 2>&1 | FileCheck %s --check-prefix=FIELD
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-partial.ll -disable-output 2>&1 | FileCheck %s --check-prefix=PARTIAL
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-phi-base.ll -disable-output 2>&1 | FileCheck %s --check-prefix=PHI

; REF: Bare memcpy/memmove of reference payload
; REF: in function reject_one_endpoint_contains_reference
; BARE: Bare memcpy/memmove payload provenance is unknown
; BARE: in function reject_untyped_as1_destination
; DYNAMIC: Bare memcpy/memmove payload provenance is unknown
; DYNAMIC: in function reject_dynamic_typeinfo_heap_write
; FIELD: Bare memcpy/memmove payload provenance is unknown
; FIELD: in function reject_dynamic_field_offset
; PARTIAL: Bare memcpy/memmove payload provenance is unknown
; PARTIAL: in function reject_partial_plain_object
; PHI: Bare memcpy/memmove payload provenance is unknown
; PHI: in function reject_selected_or_phi_base

;--- allow-as1-parent.ll
%Parent = type { i8 addrspace(1)*, i32 }

define void @allow_as1_parent_plain_subobject_to_as0(i8 addrspace(1)* %src.raw) gc "cangjie" {
entry:
  %src.parent = bitcast i8 addrspace(1)* %src.raw to %Parent addrspace(1)*
  %src.field = getelementptr inbounds %Parent, %Parent addrspace(1)* %src.parent, i32 0, i32 1
  %src.bytes = bitcast i32 addrspace(1)* %src.field to i8 addrspace(1)*
  %dst = alloca i32, align 4
  %dst.bytes = bitcast i32* %dst to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst.bytes, i8 addrspace(1)* %src.bytes, i64 4, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)

;--- allow-p0-subobject.ll
%Outer = type { i64, { i32, i32 } }

define void @allow_plain_subobject_p0_to_p0(%Outer* %src, %Outer* %dst) gc "cangjie" {
entry:
  %src.field = getelementptr inbounds %Outer, %Outer* %src, i32 0, i32 1
  %dst.field = getelementptr inbounds %Outer, %Outer* %dst, i32 0, i32 1
  %src.bytes = bitcast { i32, i32 }* %src.field to i8*
  %dst.bytes = bitcast { i32, i32 }* %dst.field to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.bytes, i8* %src.bytes, i64 8, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- allow-dynamic-native-bytes.ll
%ArrayBase = type { i64 }
%ArrayLayout.UInt8 = type { %ArrayBase, [0 x i8] }

define void @allow_dynamic_primitive_span_to_native_bytes(i8* %dst, i8 addrspace(1)* %src.raw, i64 %size) gc "cangjie" {
entry:
  %layout = bitcast i8 addrspace(1)* %src.raw to %ArrayLayout.UInt8 addrspace(1)*
  %payload = getelementptr inbounds %ArrayLayout.UInt8, %ArrayLayout.UInt8 addrspace(1)* %layout, i32 0, i32 1
  %src = bitcast [0 x i8] addrspace(1)* %payload to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst, i8 addrspace(1)* %src, i64 %size, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)

;--- allow-stack-to-heap.ll
%HeapParent = type { i8 addrspace(1)*, i32 }

define void @allow_plain_stack_to_heap_field(i8 addrspace(1)* %dst.raw, i32* %src) gc "cangjie" {
entry:
  %parent = bitcast i8 addrspace(1)* %dst.raw to %HeapParent addrspace(1)*
  %field = getelementptr inbounds %HeapParent, %HeapParent addrspace(1)* %parent, i32 0, i32 1
  %dst = bitcast i32 addrspace(1)* %field to i8 addrspace(1)*
  %src.bytes = bitcast i32* %src to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %dst, i8* %src.bytes, i64 4, i1 false)
  ret void
}

declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)

;--- allow-different-types.ll
%Left = type { i32 }
%Right = type { i16, i16 }

define void @allow_different_plain_types_same_complete_span(%Left* %dst, %Right* %src) gc "cangjie" {
entry:
  %d = bitcast %Left* %dst to i8*
  %s = bitcast %Right* %src to i8*
  call void @llvm.memmove.p0i8.p0i8.i64(i8* %d, i8* %s, i64 4, i1 false)
  ret void
}

declare void @llvm.memmove.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-reference.ll
%RefPayload = type { i8 addrspace(1)* }
%Plain = type { i64 }

define void @reject_one_endpoint_contains_reference(%Plain* %dst, %RefPayload* %src) gc "cangjie" {
entry:
  %d = bitcast %Plain* %dst to i8*
  %s = bitcast %RefPayload* %src to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d, i8* %s, i64 8, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-as1-bare-dst.ll
%Plain = type { i32 }

define void @reject_untyped_as1_destination(i8 addrspace(1)* %dst, %Plain* %src) gc "cangjie" {
entry:
  %src.bytes = bitcast %Plain* %src to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %dst, i8* %src.bytes, i64 4, i1 false)
  ret void
}

declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)

;--- reject-dynamic-size.ll
%Plain = type { i64 }

define void @reject_dynamic_typeinfo_heap_write(i8 addrspace(1)* %dst, %Plain* %src, i64 %size) gc "cangjie" {
entry:
  %s = bitcast %Plain* %src to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %dst, i8* %s, i64 %size, i1 false)
  ret void
}

declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)

;--- reject-dynamic-field.ll
%Parent = type { i32, i32 }

define void @reject_dynamic_field_offset(i8 addrspace(1)* %dst.raw, i64 %offset, i32* %src) gc "cangjie" {
entry:
  %dst = getelementptr i8, i8 addrspace(1)* %dst.raw, i64 %offset
  %s = bitcast i32* %src to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %dst, i8* %s, i64 4, i1 false)
  ret void
}

declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)

;--- reject-partial.ll
%Plain = type { i32, i32 }

define void @reject_partial_plain_object(i8 addrspace(1)* %dst, %Plain* %src) gc "cangjie" {
entry:
  %s = bitcast %Plain* %src to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %dst, i8* %s, i64 4, i1 false)
  ret void
}

declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)

;--- reject-phi-base.ll
%Plain = type { i32 }

define void @reject_selected_or_phi_base(i1 %which, i8 addrspace(1)* %a, i8 addrspace(1)* %b, %Plain* %src) gc "cangjie" {
entry:
  %dst.base = select i1 %which, i8 addrspace(1)* %a, i8 addrspace(1)* %b
  %s = bitcast %Plain* %src to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %dst.base, i8* %s, i64 4, i1 false)
  ret void
}

declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)
