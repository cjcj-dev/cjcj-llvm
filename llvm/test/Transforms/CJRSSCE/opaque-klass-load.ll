; RUN: opt -opaque-pointers=0 -passes=cj-rssce -S %s -o %t.typed.ll
; RUN: FileCheck %s --check-prefix=TYPED < %t.typed.ll
; RUN: lli -opaque-pointers=0 %t.typed.ll | FileCheck %s --check-prefix=VALUE
; RUN: opt -opaque-pointers=1 -passes=cj-rssce -S %s -o %t.opaque.ll
; RUN: FileCheck %s --check-prefix=OPAQUE < %t.opaque.ll
; RUN: lli -opaque-pointers=1 %t.opaque.ll | FileCheck %s --check-prefix=VALUE
;
; Only a reloaded address traverses the source slot's stored-value classifier.
; The actual TypeInfo data is copied into a record and read by the readonly
; consumer. A direct alloca source does not exercise isKlassGlobal.
target triple = "x86_64-unknown-linux-gnu"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
%TypeInfo = type { i8*, i64 }
%S = type { i8*, i64 }
@ti = private global %TypeInfo { i8* null, i64 13 }
@format = private constant [23 x i8] c"klass=%ld expected=13\0A\00"
declare i32 @printf(i8*, ...)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8* noalias nocapture writeonly, i8* noalias nocapture readonly, i64, i1 immarg)

define internal i64 @observe(%S* nocapture readonly %p) readonly noinline {
  %field = getelementptr %S, %S* %p, i64 0, i32 1
  %actual = load i64, i64* %field
  ret i64 %actual
}

; TYPED-LABEL: define i64 @loaded_typeinfo()
; TYPED: %result = call i64 @observe(%S* %{{[0-9]+}})
; OPAQUE-LABEL: define i64 @loaded_typeinfo()
; OPAQUE: %result = call i64 @observe(ptr %{{[0-9]+}})
define i64 @loaded_typeinfo() {
  %slot = alloca i8*
  store i8* bitcast (%TypeInfo* @ti to i8*), i8** %slot
  %loaded = load i8*, i8** %slot
  %dest = alloca %S
  %dst = bitcast %S* %dest to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %loaded, i64 16, i1 false)
  %result = call i64 @observe(%S* %dest)
  ret i64 %result
}

define i32 @main() {
  %actual = call i64 @loaded_typeinfo()
  %format = getelementptr [23 x i8], [23 x i8]* @format, i64 0, i64 0
  %printed = call i32 (i8*, ...) @printf(i8* %format, i64 %actual)
  %wrong = icmp ne i64 %actual, 13
  %rc = zext i1 %wrong to i32
  ret i32 %rc
}
; VALUE: klass=13 expected=13
