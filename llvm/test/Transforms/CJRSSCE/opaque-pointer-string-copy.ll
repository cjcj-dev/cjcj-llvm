; RUN: opt -opaque-pointers=0 -passes=cj-rssce -S < %s | FileCheck %s
; RUN: opt -opaque-pointers=1 -passes=cj-rssce -S < %s | FileCheck %s
;
; Opaque CJRSSCE must keep the element type from
; the alloca or global instead of asking the pointer type. Both functions stay
; intact: the global string copy is not deleted, and the readonly call is not
; dropped. ThinLTO qualification is separate and is not run by this fixture.

target triple = "x86_64-unknown-linux-gnu"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
@ti = private global %TypeInfo zeroinitializer
@cde = private global %"record.std.core:String" zeroinitializer

define void @copy_cde(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) {
  %dst = bitcast %"record.std.core:String"* %out to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* bitcast (%"record.std.core:String"* @cde to i8*), i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

%record.test1 = type {i8 addrspace(1)*, i64, i64}
declare void @func1(%record.test1* readonly nocapture) #0
declare void @llvm.memcpy.p0i8.p1i8.i64(i8* noalias nocapture writeonly, i8 addrspace(1)* noalias nocapture readonly, i64, i1 immarg)

define void @only_memcpy_func(i8 addrspace(1)* %ptr) {
entry:
  %slot = alloca %record.test1, align 8
  %raw = bitcast %record.test1* %slot to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* align 8 %raw, i8 addrspace(1)* align 8 %ptr, i64 24, i1 false)
  call void @func1(%record.test1* %slot)
  ret void
}

attributes #0 = { readonly }

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"CJBC", i32 1}

; CHECK-LABEL: define void @copy_cde(
; CHECK: call void @llvm.memcpy
; CHECK: ret void
; CHECK-LABEL: define void @only_memcpy_func(
; CHECK: call void @llvm.memcpy
; CHECK: call void @func1(
; CHECK: ret void
