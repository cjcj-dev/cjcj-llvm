; RUN: split-file %s %t
; RUN: not not opt -passes=cj-ir-verifier < %S/Inputs/counterexample-unknown-dst-reference-slot.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=REVIEW,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %S/Inputs/dynamic-addrspacecast-unknown.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=DYNAMIC,ABORT
; RUN: opt -passes=cj-ir-verifier < %S/Inputs/constant-cast-nonzero-offset-unknown.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=NONZERO,UNKNOWN
; RUN: not not opt -passes=cj-ir-verifier < %S/Inputs/constant-cast-reference-source.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=REFSRC,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %t/select-reference-slots.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=SELECT,ABORT

; REVIEW: Need write barrier!
; REVIEW: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]
; REVIEW: in function unknown_dst_actually_contains_reference
; DYNAMIC: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]
; DYNAMIC-NEXT: call void @llvm.memmove.p0i8.p1i8.i64
; NONZERO: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]
; NONZERO-NEXT: call void @llvm.memmove.p0i8.p1i8.i64
; REFSRC: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; REFSRC-NEXT: call void @llvm.memmove.p0i8.p1i8.i64
; REFSRC: in function constant_cast_reference_source_is_rejected
; SELECT: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]
; UNKNOWN-NOT: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; ABORT: LLVM ERROR: Broken function found, compilation aborted
; ABORT: error: Aborted

;--- select-reference-slots.ll
%RefPair = type { i8 addrspace(1)*, i8 addrspace(1)* }
@bytes = internal constant [8 x i8] zeroinitializer

; Both arms designate a managed-reference slot, but select intentionally makes
; the destination carrier untraceable to either typed object.
define void @select_between_reference_slots(i1 %choose) gc "cangjie" {
entry:
  %left = alloca %RefPair, align 8
  %right = alloca %RefPair, align 8
  %left.slot = getelementptr inbounds %RefPair, %RefPair* %left, i32 0, i32 0
  %right.slot = getelementptr inbounds %RefPair, %RefPair* %right, i32 0, i32 1
  %left.raw = addrspacecast i8 addrspace(1)** %left.slot to i8 addrspace(1)*
  %right.raw = addrspacecast i8 addrspace(1)** %right.slot to i8 addrspace(1)*
  %dst = select i1 %choose, i8 addrspace(1)* %left.raw, i8 addrspace(1)* %right.raw
  call void @llvm.memmove.p1i8.p1i8.i64(
      i8 addrspace(1)* %dst,
      i8 addrspace(1)* addrspacecast (i8* getelementptr inbounds ([8 x i8], [8 x i8]* @bytes, i32 0, i32 0) to i8 addrspace(1)*),
      i64 8, i1 false)
  ret void
}

declare void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)*, i8 addrspace(1)*, i64, i1)
