; RUN: opt -S -passes=dse --cangjie-pipeline %s | FileCheck %s

; A Cangjie generic sret is a headered addrspace(1) object sized by its
; TypeInfo. Its `sret(i8)` type must not be used as the object size, otherwise
; the 1-byte tag store is treated as overwriting the whole object and the
; payload write before it is deleted.

declare void @llvm.cj.gcwrite.generic(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)*, i32)

; CHECK-LABEL: @sret_gcwrite_then_tag(
; CHECK: call void @llvm.cj.gcwrite.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* %field, i8 addrspace(1)* %src, i32 %size)
; CHECK: store i1 false, i1 addrspace(1)* %tag
define void @sret_gcwrite_then_tag(i8 addrspace(1)* noalias sret(i8) %dst, i8 addrspace(1)* %src, i64 %off, i32 %size) gc "cangjie" {
entry:
  %payload = getelementptr inbounds i8, i8 addrspace(1)* %dst, i64 8
  %field = getelementptr inbounds i8, i8 addrspace(1)* %payload, i64 %off
  call void @llvm.cj.gcwrite.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* %field, i8 addrspace(1)* %src, i32 %size)
  %tag = bitcast i8 addrspace(1)* %payload to i1 addrspace(1)*
  store i1 false, i1 addrspace(1)* %tag, align 1
  ret void
}

; Control: the same body without sret was already kept.
; CHECK-LABEL: @noalias_gcwrite_then_tag(
; CHECK: call void @llvm.cj.gcwrite.generic(
; CHECK: store i1 false
define void @noalias_gcwrite_then_tag(i8 addrspace(1)* noalias %dst, i8 addrspace(1)* %src, i64 %off, i32 %size) gc "cangjie" {
entry:
  %payload = getelementptr inbounds i8, i8 addrspace(1)* %dst, i64 8
  %field = getelementptr inbounds i8, i8 addrspace(1)* %payload, i64 %off
  call void @llvm.cj.gcwrite.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* %field, i8 addrspace(1)* %src, i32 %size)
  %tag = bitcast i8 addrspace(1)* %payload to i1 addrspace(1)*
  store i1 false, i1 addrspace(1)* %tag, align 1
  ret void
}

; Not specific to the intrinsic: a disjoint plain store must survive too.
; CHECK-LABEL: @sret_store_then_tag(
; CHECK: store i64 %v
; CHECK: store i8 0
define void @sret_store_then_tag(i8 addrspace(1)* noalias sret(i8) %dst, i64 %v) gc "cangjie" {
entry:
  %p16 = getelementptr inbounds i8, i8 addrspace(1)* %dst, i64 16
  %q = bitcast i8 addrspace(1)* %p16 to i64 addrspace(1)*
  store i64 %v, i64 addrspace(1)* %q, align 8
  %p8 = getelementptr inbounds i8, i8 addrspace(1)* %dst, i64 8
  store i8 0, i8 addrspace(1)* %p8, align 1
  ret void
}

; Scope: an ordinary addrspace(0) sret keeps the upstream object-size rule.
; CHECK-LABEL: @as0_sret_store_then_tag(
; CHECK-NOT: store i64
; CHECK: store i8 0
define void @as0_sret_store_then_tag(i8* noalias sret(i8) %dst, i64 %v) gc "cangjie" {
entry:
  %p16 = getelementptr inbounds i8, i8* %dst, i64 16
  %q = bitcast i8* %p16 to i64*
  store i64 %v, i64* %q, align 8
  %p8 = getelementptr inbounds i8, i8* %dst, i64 8
  store i8 0, i8* %p8, align 1
  ret void
}
