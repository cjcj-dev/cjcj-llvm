; RUN: opt --cangjie-pipeline -passes=cj-object-reuse-opt -S %s -o %t
; RUN: FileCheck %s < %t
; RUN: FileCheck %s --check-prefix=CONTROL < %t
;
; cjcj#143: array constructor receivers may be reused while SROA-hoisted
; scalar field addresses still refer to the old allocation. Preserve the
; entire record when the existing whole-address rewrite cannot cover fields.
; The reference-only control must still reuse storage.
;
; CHECK-LABEL: define i64 @test(
; CHECK: call void @"record<init>"(%R addrspace(1)* %acast,
; CHECK: call void @"record<init>"(%R addrspace(1)* %bcast,
; CHECK: %result = load i64, i64* %blen
; CHECK: ret i64 %result
;
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
%R = type { i8 addrspace(1)*, i64, i64 }
%TypeInfo = type { i8*, i8, i8, i16, i32 }
@info = global %TypeInfo { i8* null, i8 22, i8 65, i16 3, i32 24 } #0

define void @"record<init>"(%R addrspace(1)* %this, i8 addrspace(1)* %raw, i64 %len, %TypeInfo* %ti) noinline {
 %ptr = getelementptr %R, %R addrspace(1)* %this, i32 0, i32 0
 store i8 addrspace(1)* %raw, i8 addrspace(1)* addrspace(1)* %ptr
 %length = getelementptr %R, %R addrspace(1)* %this, i32 0, i32 2
 store i64 %len, i64 addrspace(1)* %length
 ret void
}
define void @consume(i8 addrspace(1)* %x) noinline { ret void }

define i64 @test(i8 addrspace(1)* %raw) {
entry:
  %a = alloca %R
  %b = alloca %R
  %blen = getelementptr %R, %R* %b, i32 0, i32 2
  %aptr = getelementptr %R, %R* %a, i32 0, i32 0
  %bptr = getelementptr %R, %R* %b, i32 0, i32 0
  store %R zeroinitializer, %R* %a
  store %R zeroinitializer, %R* %b
  %acast = addrspacecast %R* %a to %R addrspace(1)*
  call void @"record<init>"(%R addrspace(1)* %acast, i8 addrspace(1)* %raw, i64 1, %TypeInfo* @info)
  %av = load i8 addrspace(1)*, i8 addrspace(1)** %aptr
  call void @consume(i8 addrspace(1)* %av)
  %bcast = addrspacecast %R* %b to %R addrspace(1)*
  call void @"record<init>"(%R addrspace(1)* %bcast, i8 addrspace(1)* %raw, i64 8, %TypeInfo* @info)
  %bv = load i8 addrspace(1)*, i8 addrspace(1)** %bptr
  call void @consume(i8 addrspace(1)* %bv)
  %result = load i64, i64* %blen
  ret i64 %result
}
attributes #0 = { "NotModifiableClass" }

define i32 @main() {
 %size = call i64 @test(i8 addrspace(1)* null)
 %ok = icmp eq i64 %size, 8
 %rc = select i1 %ok, i32 0, i32 17
 ret i32 %rc
}

; CONTROL-LABEL: define void @reference_only(
; CONTROL: call void @"record<init>"(%R addrspace(1)* %acast,
; CONTROL: call void @"record<init>"(%R addrspace(1)* %acast,
; CONTROL: %bv = load i8 addrspace(1)*, i8 addrspace(1)** %aptr
; CONTROL: ret void

define void @reference_only(i8 addrspace(1)* %raw) {
entry:
  %a = alloca %R
  %b = alloca %R
  %aptr = getelementptr %R, %R* %a, i32 0, i32 0
  %bptr = getelementptr %R, %R* %b, i32 0, i32 0
  store %R zeroinitializer, %R* %a
  store %R zeroinitializer, %R* %b
  %acast = addrspacecast %R* %a to %R addrspace(1)*
  call void @"record<init>"(%R addrspace(1)* %acast, i8 addrspace(1)* %raw, i64 1, %TypeInfo* @info)
  %av = load i8 addrspace(1)*, i8 addrspace(1)** %aptr
  call void @consume(i8 addrspace(1)* %av)
  %bcast = addrspacecast %R* %b to %R addrspace(1)*
  call void @"record<init>"(%R addrspace(1)* %bcast, i8 addrspace(1)* %raw, i64 8, %TypeInfo* @info)
  %bv = load i8 addrspace(1)*, i8 addrspace(1)** %bptr
  call void @consume(i8 addrspace(1)* %bv)
  ret void
}
