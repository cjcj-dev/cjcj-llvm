; RUN: opt -opaque-pointers=0 -passes=cj-rssce -S %s -o %t.typed.ll
; RUN: FileCheck %s --check-prefix=TYPED < %t.typed.ll
; RUN: lli -opaque-pointers=0 %t.typed.ll
; RUN: opt -opaque-pointers=1 -passes=cj-rssce -S %s -o %t.opaque.ll
; RUN: FileCheck %s --check-prefix=OPAQUE < %t.opaque.ll
; RUN: lli -opaque-pointers=1 %t.opaque.ll
;
; The source contains a TypeInfo address and lives in AS1. Its actual readonly
; consumer observes the copied integer after the product rewrites its argument
; across address spaces. An unrelated opaque argument must remain unchanged.
target triple = "x86_64-unknown-linux-gnu"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
%TypeInfo = type { i64 }
%S = type { i8*, i64 }
@ti = private global %TypeInfo zeroinitializer

declare void @llvm.memcpy.p0i8.p1i8.i64(i8* noalias nocapture writeonly, i8 addrspace(1)* noalias nocapture readonly, i64, i1 immarg)
declare void @unknown_observer(i8* nocapture readonly)

define internal i64 @observe(%S* nocapture readonly %p) readonly noinline {
  %field = getelementptr %S, %S* %p, i64 0, i32 1
  %value = load i64, i64* %field
  ret i64 %value
}

; TYPED-LABEL: define i64 @cross_address_space()
; TYPED: %[[CAST:.*]] = addrspacecast i8 addrspace(1)* {{.*}} to i8*
; TYPED: %[[ARG:.*]] = bitcast i8* %[[CAST]] to %S*
; TYPED: %result = call i64 @observe(%S* %[[ARG]])
; OPAQUE-LABEL: define i64 @cross_address_space()
; OPAQUE: %[[CAST:.*]] = addrspacecast ptr addrspace(1) {{.*}} to ptr
; OPAQUE: %result = call i64 @observe(ptr %[[CAST]])
define i64 @cross_address_space() {
  %source = alloca %S, addrspace(1)
  %klass = getelementptr %S, %S addrspace(1)* %source, i64 0, i32 0
  store i8* bitcast (%TypeInfo* @ti to i8*), i8* addrspace(1)* %klass
  %field = getelementptr %S, %S addrspace(1)* %source, i64 0, i32 1
  store i64 13, i64 addrspace(1)* %field
  %dest = alloca %S
  %dst = bitcast %S* %dest to i8*
  %src = bitcast %S addrspace(1)* %source to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst, i8 addrspace(1)* %src, i64 16, i1 false)
  %result = call i64 @observe(%S* %dest)
  ret i64 %result
}

; TYPED-LABEL: define void @unknown_type(
; TYPED: call void @unknown_observer(i8* %p)
; OPAQUE-LABEL: define void @unknown_type(
; OPAQUE: call void @unknown_observer(ptr %p)
define void @unknown_type(i8* %p) {
  call void @unknown_observer(i8* %p)
  ret void
}

define i32 @main() {
  %actual = call i64 @cross_address_space()
  %wrong = icmp ne i64 %actual, 13
  %rc = zext i1 %wrong to i32
  ret i32 %rc
}
