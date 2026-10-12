; RUN: opt -opaque-pointers=0 -passes=cj-rssce -S %s -o %t.typed.ll
; RUN: FileCheck %s --check-prefix=TYPED < %t.typed.ll
; RUN: lli -opaque-pointers=0 %t.typed.ll | FileCheck %s --check-prefix=VALUE
; RUN: opt -opaque-pointers=1 -passes=cj-rssce -S %s -o %t.opaque.ll
; RUN: FileCheck %s --check-prefix=OPAQUE < %t.opaque.ll
; RUN: lli -opaque-pointers=1 %t.opaque.ll | FileCheck %s --check-prefix=VALUE
;
; A slot reload must not classify arbitrary AS0 addresses as TypeInfo.
; Storage type and address space remain explicit with opaque pointers.
; A typed non-byte TypeInfo address retains the old byte-view restriction;
; opaque mode has erased that use type and uses the known global definition.
target triple = "x86_64-unknown-linux-gnu"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
%TypeInfo = type { i8*, i64 }
%Ordinary = type { i8*, i64 }
%S = type { i8*, i64 }
@ordinary = private global %Ordinary { i8* null, i64 17 }
@anonymous = private global { i8*, i64 } { i8* null, i64 19 }
@array = private global [2 x i64] [i64 0, i64 23]
@ti1 = private addrspace(1) global %TypeInfo { i8* null, i64 29 }
@ti = private global %TypeInfo { i8* null, i64 13 }
declare i32 @printf(i8*, ...)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8* noalias nocapture writeonly, i8* noalias nocapture readonly, i64, i1 immarg)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8* noalias nocapture writeonly, i8 addrspace(1)* noalias nocapture readonly, i64, i1 immarg)

define internal i64 @observe(%S* nocapture readonly %p) readonly noinline {
  %field = getelementptr %S, %S* %p, i64 0, i32 1
  %actual = load i64, i64* %field
  ret i64 %actual
}

; TYPED-LABEL: define i64 @case_ordinary(
; TYPED: %result = call i64 @observe(%S* %dest)

; OPAQUE-LABEL: define i64 @case_ordinary(
; OPAQUE: %result = call i64 @observe(ptr %dest)
define i64 @case_ordinary() {
  %slot = alloca i8*
  store i8* bitcast (%Ordinary* @ordinary to i8*), i8** %slot
  %loaded = load i8*, i8** %slot
  %dest = alloca %S
  %dst = bitcast %S* %dest to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %loaded, i64 16, i1 false)
  %result = call i64 @observe(%S* %dest)
  ret i64 %result
}

; TYPED-LABEL: define i64 @case_anonymous(
; TYPED: %result = call i64 @observe(%S* %dest)

; OPAQUE-LABEL: define i64 @case_anonymous(
; OPAQUE: %result = call i64 @observe(ptr %dest)
define i64 @case_anonymous() {
  %slot = alloca i8*
  store i8* bitcast ({ i8*, i64 }* @anonymous to i8*), i8** %slot
  %loaded = load i8*, i8** %slot
  %dest = alloca %S
  %dst = bitcast %S* %dest to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %loaded, i64 16, i1 false)
  %result = call i64 @observe(%S* %dest)
  ret i64 %result
}

; TYPED-LABEL: define i64 @case_array(
; TYPED: %result = call i64 @observe(%S* %dest)

; OPAQUE-LABEL: define i64 @case_array(
; OPAQUE: %result = call i64 @observe(ptr %dest)
define i64 @case_array() {
  %slot = alloca i8*
  store i8* bitcast ([2 x i64]* @array to i8*), i8** %slot
  %loaded = load i8*, i8** %slot
  %dest = alloca %S
  %dst = bitcast %S* %dest to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %loaded, i64 16, i1 false)
  %result = call i64 @observe(%S* %dest)
  ret i64 %result
}

; TYPED-LABEL: define i64 @case_unknown(
; TYPED: %result = call i64 @observe(%S* %dest)

; OPAQUE-LABEL: define i64 @case_unknown(
; OPAQUE: %result = call i64 @observe(ptr %dest)
define i64 @case_unknown(i8* %arg) {
  %slot = alloca i8*
  store i8* %arg, i8** %slot
  %loaded = load i8*, i8** %slot
  %dest = alloca %S
  %dst = bitcast %S* %dest to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %loaded, i64 16, i1 false)
  %result = call i64 @observe(%S* %dest)
  ret i64 %result
}

; TYPED-LABEL: define i64 @case_as1(
; TYPED: %result = call i64 @observe(%S* %dest)

; OPAQUE-LABEL: define i64 @case_as1(
; OPAQUE: %result = call i64 @observe(ptr %dest)
define i64 @case_as1() {
  %slot = alloca i8 addrspace(1)*
  store i8 addrspace(1)* bitcast (%TypeInfo addrspace(1)* @ti1 to i8 addrspace(1)*), i8 addrspace(1)** %slot
  %loaded = load i8 addrspace(1)*, i8 addrspace(1)** %slot
  %dest = alloca %S
  %dst = bitcast %S* %dest to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst, i8 addrspace(1)* %loaded, i64 16, i1 false)
  %result = call i64 @observe(%S* %dest)
  ret i64 %result
}

; TYPED-LABEL: define i64 @case_nonbyte(
; TYPED: %result = call i64 @observe(%S* %dest)

; OPAQUE-LABEL: define i64 @case_nonbyte(
; OPAQUE: %result = call i64 @observe(ptr %{{[0-9]+}})
define i64 @case_nonbyte() {
  %slot = alloca %TypeInfo*
  store %TypeInfo* @ti, %TypeInfo** %slot
  %loaded = load %TypeInfo*, %TypeInfo** %slot
  %dest = alloca %S
  %dst = bitcast %S* %dest to i8*
  %bytes = bitcast %TypeInfo* %loaded to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %bytes, i64 16, i1 false)
  %result = call i64 @observe(%S* %dest)
  ret i64 %result
}

@format = private constant [61 x i8] c"controls=%ld,%ld,%ld,%ld,%ld,%ld expected=17,19,23,17,29,13\0A\00"

define i32 @main() {
  %v0 = call i64 @case_ordinary()
  %v1 = call i64 @case_anonymous()
  %v2 = call i64 @case_array()
  %v3 = call i64 @case_unknown(i8* bitcast (%Ordinary* @ordinary to i8*))
  %v4 = call i64 @case_as1()
  %v5 = call i64 @case_nonbyte()
  %fmt = getelementptr [61 x i8], [61 x i8]* @format, i64 0, i64 0
  %print = call i32 (i8*, ...) @printf(i8* %fmt, i64 %v0, i64 %v1, i64 %v2, i64 %v3, i64 %v4, i64 %v5)
  %wrong0 = icmp ne i64 %v0, 17
  %wrong1 = icmp ne i64 %v1, 19
  %wrong2 = icmp ne i64 %v2, 23
  %wrong3 = icmp ne i64 %v3, 17
  %wrong4 = icmp ne i64 %v4, 29
  %wrong5 = icmp ne i64 %v5, 13
  %any1 = or i1 %wrong0, %wrong1
  %any2 = or i1 %any1, %wrong2
  %any3 = or i1 %any2, %wrong3
  %any4 = or i1 %any3, %wrong4
  %any5 = or i1 %any4, %wrong5
  %rc = zext i1 %any5 to i32
  ret i32 %rc
}
; VALUE: controls=17,19,23,17,29,13 expected=17,19,23,17,29,13
