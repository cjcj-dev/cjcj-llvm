; RUN: opt -passes=cj-runtime-lowering -S < %s | FileCheck %s
; RUN: opt -cj-runtime-lowering -S < %s | FileCheck %s
; RUN: opt -passes='cj-runtime-lowering,function(sroa)' -S < %s | FileCheck %s --check-prefix=SROA
; Existing typed payload contract; no frontend or verifier relaxation.
target datalayout = "e-m:e-p:64:64-i64:64-n8:16:32:64-S128"
%Pair = type { i8, i8 }
%Other = type { i16 }
%Ref = type { i8 addrspace(1)* }
declare void @llvm.cj.copy.no.ref.struct.i64(i8*, i8*, i64)

; CHECK-LABEL: define void @local_to_result(
; CHECK: call void @llvm.memcpy.p0i8.p0i8.i64
; CHECK-NOT: call void @llvm.cj.copy.no.ref.struct
; CHECK: ret void
; SROA-LABEL: define void @local_to_result(
; SROA-NOT: alloca
; SROA-NOT: call void @llvm.cj.copy.no.ref.struct
; SROA: store
; SROA: ret void
define void @local_to_result(%Pair* noalias sret(%Pair) %dst, i8 %x) {
entry:
  %src = alloca %Pair
  %first = getelementptr %Pair, %Pair* %src, i32 0, i32 0
  %second = getelementptr %Pair, %Pair* %src, i32 0, i32 1
  store i8 %x, i8* %first
  store i8 7, i8* %second
  %s = bitcast %Pair* %src to i8*
  %d = bitcast %Pair* %dst to i8*
  call void @llvm.cj.copy.no.ref.struct.i64(i8* %d, i8* %s, i64 2), !AggType !0
  ret void
}

; CHECK-LABEL: define i8 @distinct_locals(
; CHECK: call void @llvm.memcpy.p0i8.p0i8.i64
; CHECK-NOT: call void @llvm.cj.copy.no.ref.struct
; CHECK: ret i8
; SROA-LABEL: define i8 @distinct_locals(
; SROA-NOT: alloca
; SROA-NOT: call void @llvm.cj.copy.no.ref.struct
; SROA: ret i8 %x
define i8 @distinct_locals(i8 %x) {
entry:
  %src = alloca %Pair
  %dst = alloca %Pair
  %first = getelementptr %Pair, %Pair* %src, i32 0, i32 0
  store i8 %x, i8* %first
  %s = bitcast %Pair* %src to i8*
  %d = bitcast %Pair* %dst to i8*
  call void @llvm.cj.copy.no.ref.struct.i64(i8* %d, i8* %s, i64 2), !AggType !0
  %value = load i8, i8* %d
  ret i8 %value
}

; Unknown native pointer is not made trustworthy by AggType.
; CHECK-LABEL: define void @unknown_source(
; CHECK-NOT: call void @llvm.memcpy
; CHECK: call void @llvm.cj.copy.no.ref.struct.i64
; CHECK: ret void
define void @unknown_source(i8* %src) {
  %dst = alloca %Pair
  %d = bitcast %Pair* %dst to i8*
  call void @llvm.cj.copy.no.ref.struct.i64(i8* %d, i8* %src, i64 2), !AggType !0
  ret void
}

; An explicit managed-to-native cast cannot establish native ownership.
; CHECK-LABEL: define void @managed_cast(
; CHECK-NOT: call void @llvm.memcpy
; CHECK: call void @llvm.cj.copy.no.ref.struct.i64
; CHECK: ret void
define void @managed_cast(%Pair addrspace(1)* %src) {
  %dst = alloca %Pair
  %d = bitcast %Pair* %dst to i8*
  %cast = addrspacecast %Pair addrspace(1)* %src to %Pair*
  %s = bitcast %Pair* %cast to i8*
  call void @llvm.cj.copy.no.ref.struct.i64(i8* %d, i8* %s, i64 2), !AggType !0
  ret void
}

; Standalone lowering must not hide a malformed size from a later verifier.
; CHECK-LABEL: define void @partial_copy(
; CHECK-NOT: call void @llvm.memcpy
; CHECK: call void @llvm.cj.copy.no.ref.struct.i64
; CHECK: ret void
define void @partial_copy(%Pair* noalias sret(%Pair) %dst) {
  %src = alloca %Pair
  %s = bitcast %Pair* %src to i8*
  %d = bitcast %Pair* %dst to i8*
  call void @llvm.cj.copy.no.ref.struct.i64(i8* %d, i8* %s, i64 1), !AggType !0
  ret void
}

; Same address or subobject ranges are outside the disjoint whole-object rule.
; CHECK-LABEL: define void @same_object(
; CHECK-NOT: call void @llvm.memcpy
; CHECK: call void @llvm.cj.copy.no.ref.struct.i64
; CHECK: ret void
define void @same_object() {
  %obj = alloca %Pair
  %p = bitcast %Pair* %obj to i8*
  call void @llvm.cj.copy.no.ref.struct.i64(i8* %p, i8* %p, i64 2), !AggType !0
  ret void
}
; CHECK-LABEL: define void @nonzero_offset(
; CHECK-NOT: call void @llvm.memcpy
; CHECK: call void @llvm.cj.copy.no.ref.struct.i64
; CHECK: ret void
define void @nonzero_offset(%Pair* noalias sret(%Pair) %dst) {
  %src = alloca %Pair
  %s = getelementptr %Pair, %Pair* %src, i32 0, i32 1
  %d = bitcast %Pair* %dst to i8*
  call void @llvm.cj.copy.no.ref.struct.i64(i8* %d, i8* %s, i64 2), !AggType !0
  ret void
}
; CHECK-LABEL: define void @different_object_type(
; CHECK-NOT: call void @llvm.memcpy
; CHECK: call void @llvm.cj.copy.no.ref.struct.i64
; CHECK: ret void
define void @different_object_type(%Pair* noalias sret(%Pair) %dst) {
  %src = alloca %Other
  %s = bitcast %Other* %src to i8*
  %d = bitcast %Pair* %dst to i8*
  call void @llvm.cj.copy.no.ref.struct.i64(i8* %d, i8* %s, i64 2), !AggType !0
  ret void
}

; No-ref metadata cannot excuse reference-bearing storage, even in AS0.
; CHECK-LABEL: define void @reference_payload(
; CHECK-NOT: call void @llvm.memcpy
; CHECK: call void @llvm.cj.copy.no.ref.struct.i64
; CHECK: ret void
define void @reference_payload(%Ref* noalias sret(%Ref) %dst) {
  %src = alloca %Ref
  %s = bitcast %Ref* %src to i8*
  %d = bitcast %Ref* %dst to i8*
  call void @llvm.cj.copy.no.ref.struct.i64(i8* %d, i8* %s, i64 8), !AggType !1
  ret void
}
!0 = !{!"Pair"}
!1 = !{!"Ref"}
