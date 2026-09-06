; RUN: split-file %s %t
; RUN: opt -passes=cj-ir-verifier < %t/allow-as1-parent.ll -disable-output
; RUN: opt -passes=cj-ir-verifier < %t/allow-p0-subobject.ll -disable-output
; RUN: opt -passes=cj-ir-verifier < %t/allow-dynamic-native-bytes.ll -disable-output
; RUN: opt -passes=cj-ir-verifier < %t/allow-stack-to-heap.ll -disable-output
; RUN: opt -passes=cj-ir-verifier < %t/allow-different-types.ll -disable-output
; RUN: opt -passes=cj-ir-verifier < %t/allow-as0-entry-alloca-ref.ll -disable-output
; RUN: opt -passes=cj-ir-verifier < %t/attack-as0-two-load-ref.ll -disable-output 2>&1 | FileCheck %s --check-prefix=AS0LOADREF
; RUN: opt -passes=cj-ir-verifier < %t/attack-as0-two-call-ref.ll -disable-output 2>&1 | FileCheck %s --check-prefix=AS0CALLREF
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-reference.ll -disable-output 2>&1 | FileCheck %s --check-prefix=REF
; RUN: opt -passes=cj-ir-verifier < %t/reject-as1-bare-dst.ll -disable-output 2>&1 | FileCheck %s --check-prefix=BARE
; RUN: opt -passes=cj-ir-verifier < %t/reject-dynamic-size.ll -disable-output 2>&1 | FileCheck %s --check-prefix=DYNAMIC
; RUN: opt -passes=cj-ir-verifier < %t/reject-dynamic-field.ll -disable-output 2>&1 | FileCheck %s --check-prefix=FIELD
; RUN: opt -passes=cj-ir-verifier < %t/reject-partial.ll -disable-output 2>&1 | FileCheck %s --check-prefix=PARTIAL
; RUN: opt -passes=cj-ir-verifier < %t/reject-phi-base.ll -disable-output 2>&1 | FileCheck %s --check-prefix=PHI
; RUN: not not opt -passes=cj-ir-verifier < %t/attack-ascast-native.ll -disable-output 2>&1 | FileCheck %s --check-prefix=ASCAST
; RUN: not not opt -passes=cj-ir-verifier < %t/attack-bitcast-gep-pun.ll -disable-output 2>&1 | FileCheck %s --check-prefix=PUN
; RUN: opt -passes=cj-ir-verifier < %t/attack-i8-gep-as1.ll -disable-output 2>&1 | FileCheck %s --check-prefix=I8GEP
; RUN: opt -passes=cj-ir-verifier < %t/attack-load-as1.ll -disable-output 2>&1 | FileCheck %s --check-prefix=LOAD
; RUN: opt -passes=cj-ir-verifier < %t/attack-call-as1.ll -disable-output 2>&1 | FileCheck %s --check-prefix=CALL
; RUN: not not opt -passes=cj-ir-verifier < %t/attack-partial-ref-field.ll -disable-output 2>&1 | FileCheck %s --check-prefix=PARTIALREF

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
; ASCAST: Bare memcpy/memmove payload provenance is unknown
; ASCAST: in function attack_ascast_heap_to_as0_arg
; PUN: Bare memcpy/memmove of reference payload
; PUN: in function attack_bitcast_then_gep
; I8GEP: Bare memcpy/memmove payload provenance is unknown
; I8GEP: in function attack_i8_gep_as1_one_byte
; LOAD: Bare memcpy/memmove payload provenance is unknown
; LOAD: in function attack_loaded_pointer
; CALL: Bare memcpy/memmove payload provenance is unknown
; CALL: in function attack_called_pointer
; PARTIALREF: Bare memcpy/memmove of reference payload
; PARTIALREF: in function attack_partial_nested_ref
; AS0LOADREF: Bare memcpy/memmove payload provenance is unknown
; AS0LOADREF: in function attack_as0_two_loaded_ref_objects
; AS0CALLREF: Bare memcpy/memmove payload provenance is unknown
; AS0CALLREF: in function attack_as0_two_called_ref_objects

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

;--- attack-ascast-native.ll
%ArrayBase = type { i64 }
%ArrayLayout.UInt8 = type { %ArrayBase, [0 x i8] }
define void @attack_ascast_heap_to_as0_arg(i8 addrspace(1)* %heap, i8 addrspace(1)* %src.raw, i64 %size) gc "cangjie" {
entry:
  %dst = addrspacecast i8 addrspace(1)* %heap to i8*
  %layout = bitcast i8 addrspace(1)* %src.raw to %ArrayLayout.UInt8 addrspace(1)*
  %payload = getelementptr inbounds %ArrayLayout.UInt8, %ArrayLayout.UInt8 addrspace(1)* %layout, i32 0, i32 1
  %src = bitcast [0 x i8] addrspace(1)* %payload to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst, i8 addrspace(1)* %src, i64 %size, i1 false)
  ret void
}
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)

;--- attack-bitcast-gep-pun.ll
; Type pun: bitcast ref struct to fake {i32,i32} then GEP field 0 (4 bytes).
%Ref = type { i8 addrspace(1)* }
%Fake = type { i32, i32 }

define void @attack_bitcast_then_gep(%Ref* %src, i32* %dst) gc "cangjie" {
entry:
  %fake = bitcast %Ref* %src to %Fake*
  %field = getelementptr inbounds %Fake, %Fake* %fake, i32 0, i32 0
  %s = bitcast i32* %field to i8*
  %d = bitcast i32* %dst to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d, i8* %s, i64 4, i1 false)
  ret void
}
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- attack-i8-gep-as1.ll
; Attack: no-op i8 GEP on bare AS1 carriers should not prove a 1-byte complete object.
define void @attack_i8_gep_as1_one_byte(i8 addrspace(1)* %dst, i8 addrspace(1)* %src) gc "cangjie" {
entry:
  %d = getelementptr i8, i8 addrspace(1)* %dst, i32 0
  %s = getelementptr i8, i8 addrspace(1)* %src, i32 0
  call void @llvm.memcpy.p1i8.p1i8.i64(i8 addrspace(1)* %d, i8 addrspace(1)* %s, i64 1, i1 false)
  ret void
}
declare void @llvm.memcpy.p1i8.p1i8.i64(i8 addrspace(1)*, i8 addrspace(1)*, i64, i1)

;--- attack-load-as1.ll
%Plain = type { i32 }
define void @attack_loaded_pointer(%Plain addrspace(1)** %slot, %Plain* %src) gc "cangjie" {
entry:
  %dst = load %Plain addrspace(1)*, %Plain addrspace(1)** %slot
  %d = bitcast %Plain addrspace(1)* %dst to i8 addrspace(1)*
  %s = bitcast %Plain* %src to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %d, i8* %s, i64 4, i1 false)
  ret void
}
declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)

;--- attack-call-as1.ll
%Plain = type { i32 }
define void @attack_called_pointer(%Plain* %src) gc "cangjie" {
entry:
  %dst = call %Plain addrspace(1)* @get_plain()
  %d = bitcast %Plain addrspace(1)* %dst to i8 addrspace(1)*
  %s = bitcast %Plain* %src to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %d, i8* %s, i64 4, i1 false)
  ret void
}
declare %Plain addrspace(1)* @get_plain()
declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)

;--- attack-partial-ref-field.ll
; Parent has ref; GEP selects nested struct that itself has a ref; copy partial 4 of 16.
%Inner = type { i8 addrspace(1)*, i32 }
%Outer = type { i64, %Inner }
define void @attack_partial_nested_ref(%Outer addrspace(1)* %src.p, i8 addrspace(1)* %dst) gc "cangjie" {
entry:
  %inner = getelementptr inbounds %Outer, %Outer addrspace(1)* %src.p, i32 0, i32 1
  %s = bitcast %Inner addrspace(1)* %inner to i8 addrspace(1)*
  call void @llvm.memcpy.p1i8.p1i8.i64(i8 addrspace(1)* %dst, i8 addrspace(1)* %s, i64 4, i1 false)
  ret void
}
declare void @llvm.memcpy.p1i8.p1i8.i64(i8 addrspace(1)*, i8 addrspace(1)*, i64, i1)

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

;--- allow-as0-entry-alloca-ref.ll
%HasRef = type { i8 addrspace(1)*, i64 }

define void @allow_as0_entry_alloca_ref() gc "cangjie" {
entry:
  %src = alloca %HasRef, align 8
  %dst = alloca %HasRef, align 8
  %src.b = bitcast %HasRef* %src to i8*
  %dst.b = bitcast %HasRef* %dst to i8*
  call void @llvm.cj.memset(i8* %src.b, i8 0, i64 16, i1 false)
  call void @llvm.cj.memset(i8* %dst.b, i8 0, i64 16, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.b, i8* %src.b, i64 16, i1 false)
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- attack-as0-two-load-ref.ll
%HasRef = type { i8 addrspace(1)*, i64 }

define void @attack_as0_two_loaded_ref_objects(%HasRef** %slot1, %HasRef** %slot2) gc "cangjie" {
entry:
  %p = load %HasRef*, %HasRef** %slot1
  %q = load %HasRef*, %HasRef** %slot2
  %src.b = bitcast %HasRef* %p to i8*
  %dst.b = bitcast %HasRef* %q to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.b, i8* %src.b, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- attack-as0-two-call-ref.ll
%HasRef = type { i8 addrspace(1)*, i64 }
declare %HasRef* @make_ref()

define void @attack_as0_two_called_ref_objects() gc "cangjie" {
entry:
  %p = call %HasRef* @make_ref()
  %q = call %HasRef* @make_ref()
  %src.b = bitcast %HasRef* %p to i8*
  %dst.b = bitcast %HasRef* %q to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.b, i8* %src.b, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

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
