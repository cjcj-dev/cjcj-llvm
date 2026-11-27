; RUN: split-file %s %t
; RUN: opt -passes=cj-ir-verifier < %t/pos-alloca.ll -disable-output 2>&1 | FileCheck %s --allow-empty -check-prefix=POS
; RUN: opt -passes=cj-ir-verifier < %t/pos-arg-global.ll -disable-output 2>&1 | FileCheck %s --allow-empty -check-prefix=POS
; RUN: opt -passes=cj-ir-verifier < %t/neg-as1-carrier.ll -disable-output 2>&1 | FileCheck %s -check-prefix=AS1
; RUN: opt -passes=cj-ir-verifier < %t/neg-selected-base.ll -disable-output 2>&1 | FileCheck %s -check-prefix=SEL
; RUN: opt -passes=cj-ir-verifier < %t/cast-between-gep-and-root.ll -disable-output 2>&1 | FileCheck %s --allow-empty -check-prefix=CAST
; RUN: not not opt -passes=cj-ir-verifier < %t/neg-reference-field.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=REF,ABORT

; Plain field/tuple-element copies between AS0 allocas, arguments and globals
; recover complete, same-size, GC-pointer-free regions on both sides; they
; must not be reported as [silent-exit:multi-index].
; POS-NOT: unknown-payload
; POS-NOT: silent-exit
; POS-NOT: LLVM ERROR

; An AS1 field carrier stays on the multi-index report path.
; AS1: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [silent-exit:multi-index] [unknown-payload:report]
; AS1-NEXT: call void @llvm.memcpy.p0i8.p1i8.i64
; AS1-NEXT: in function neg_as1_field_carrier
; AS1-NOT: LLVM ERROR

; Selected (select/phi) bases are not declared roots and stay reported.
; SEL: [unknown-payload:report]
; SEL-NEXT: call void @llvm.memcpy.p0i8.p0i8.i64
; SEL-NEXT: in function neg_selected_base
; SEL: [unknown-payload:report]
; SEL-NEXT: call void @llvm.memcpy.p0i8.p0i8.i64
; SEL-NEXT: in function neg_phi_base
; SEL-NOT: LLVM ERROR

; A cast between the field GEP and its declaration does not satisfy the
; declared-root gate.  isNoReferenceMemTransfer does not recover this region,
; so the copy reaches the pre-existing complete non-heap admission both with
; and without the gate; the gate must not change this outcome.
; CAST-NOT: silent-exit
; CAST-NOT: LLVM ERROR

; A reference-bearing AS0 field copy is still a hard failure.
; REF: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; REF-NEXT: call void @llvm.memcpy.p0i8.p0i8.i64
; REF-NEXT: in function neg_reference_field_global_source
; ABORT: LLVM ERROR: Broken function found, compilation aborted

;--- pos-alloca.ll
%Pair = type { i64, i64 }
%Outer = type { i64, %Pair }

define void @pos_alloca_field_copy() gc "cangjie" {
entry:
  %a = alloca %Outer, align 8
  %b = alloca %Outer, align 8
  %dst.field = getelementptr inbounds %Outer, %Outer* %a, i32 0, i32 1
  %src.field = getelementptr inbounds %Outer, %Outer* %b, i32 0, i32 1
  %dst = bitcast %Pair* %dst.field to i8*
  %src = bitcast %Pair* %src.field to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- pos-arg-global.ll
%Pair = type { i64, i64 }
%Tuple = type { i32, %Pair, double }

@g = internal global %Tuple zeroinitializer, align 8

define void @pos_argument_global_tuple_field(%Tuple* %out) gc "cangjie" {
entry:
  %dst.field = getelementptr inbounds %Tuple, %Tuple* %out, i32 0, i32 1
  %src.field = getelementptr inbounds %Tuple, %Tuple* @g, i32 0, i32 1
  %dst = bitcast %Pair* %dst.field to i8*
  %src = bitcast %Pair* %src.field to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- neg-as1-carrier.ll
%Pair = type { i64, i64 }
%Outer = type { i64, %Pair }

define void @neg_as1_field_carrier(i8 addrspace(1)* %object) gc "cangjie" {
entry:
  %a = alloca %Outer, align 8
  %dst.field = getelementptr inbounds %Outer, %Outer* %a, i32 0, i32 1
  %dst = bitcast %Pair* %dst.field to i8*
  %obj = bitcast i8 addrspace(1)* %object to %Outer addrspace(1)*
  %src.field = getelementptr inbounds %Outer, %Outer addrspace(1)* %obj, i32 0, i32 1
  %src = bitcast %Pair addrspace(1)* %src.field to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst, i8 addrspace(1)* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)

;--- neg-selected-base.ll
%Pair = type { i64, i64 }
%Outer = type { i64, %Pair }

define void @neg_selected_base(i1 %c) gc "cangjie" {
entry:
  %a = alloca %Outer, align 8
  %b = alloca %Pair, align 8
  %e = alloca %Pair, align 8
  %dst.field = getelementptr inbounds %Outer, %Outer* %a, i32 0, i32 1
  %dst = bitcast %Pair* %dst.field to i8*
  %sel = select i1 %c, %Pair* %b, %Pair* %e
  %src = bitcast %Pair* %sel to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

define void @neg_phi_base(i1 %c) gc "cangjie" {
entry:
  %a = alloca %Outer, align 8
  %b = alloca %Outer, align 8
  %e = alloca %Outer, align 8
  br i1 %c, label %left, label %right
left:
  br label %join
right:
  br label %join
join:
  %base = phi %Outer* [ %b, %left ], [ %e, %right ]
  %dst.field = getelementptr inbounds %Outer, %Outer* %a, i32 0, i32 1
  %src.field = getelementptr inbounds %Outer, %Outer* %base, i32 0, i32 1
  %dst = bitcast %Pair* %dst.field to i8*
  %src = bitcast %Pair* %src.field to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- cast-between-gep-and-root.ll
%Pair = type { i64, i64 }
%Outer = type { i64, %Pair }
%OuterView = type { i64, %Pair }
%Wrap = type { %Outer }

define void @cast_between_gep_and_root() gc "cangjie" {
entry:
  %a = alloca %Outer, align 8
  %w = alloca %Wrap, align 8
  %inner = getelementptr inbounds %Wrap, %Wrap* %w, i32 0, i32 0
  %view = bitcast %Outer* %inner to %OuterView*
  %dst.field = getelementptr inbounds %Outer, %Outer* %a, i32 0, i32 1
  %src.field = getelementptr inbounds %OuterView, %OuterView* %view, i32 0, i32 1
  %dst = bitcast %Pair* %dst.field to i8*
  %src = bitcast %Pair* %src.field to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- neg-reference-field.ll
%RefPair = type { i8 addrspace(1)*, i64 }
%Outer = type { i64, %RefPair }

@g = internal global %Outer zeroinitializer, align 8

define void @neg_reference_field_global_source(%Outer* %out) gc "cangjie" {
entry:
  %dst.field = getelementptr inbounds %Outer, %Outer* %out, i32 0, i32 1
  %src.field = getelementptr inbounds %Outer, %Outer* @g, i32 0, i32 1
  %dst = bitcast %RefPair* %dst.field to i8*
  %src = bitcast %RefPair* %src.field to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
