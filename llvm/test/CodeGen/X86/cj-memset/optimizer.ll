; RUN: opt -passes=cj-specific-opt -cangjie-JIT=true -S < %s | FileCheck %s
; RUN: opt -enable-new-pm=false -cj-specific-opt -cangjie-JIT=true -S < %s | FileCheck %s
; The shared dispatcher must preserve both optimizer pass-manager entry points:
; full intrinsic lowering for managed functions, and the existing optnone skip.
target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"

; CHECK-LABEL: define double @optimized(
; CHECK: call void @llvm.memset.p0i8.i64(i8* %dst, i8 0, i64 8, i1 false)
; CHECK: %p = call double @CJ_CORE_CPow(double %x, double %y)
; CHECK: ret double %p
define double @optimized(i8* %dst, double %x, double %y) gc "cangjie" {
  call void @llvm.cj.memset(i8* %dst, i8 0, i64 8, i1 false)
  %p = call double @llvm.pow.f64(double %x, double %y)
  ret double %p
}

; CHECK-LABEL: define double @unoptimized(
; CHECK: call void @llvm.cj.memset(i8* %dst, i8 0, i64 8, i1 false)
; CHECK: %p = call double @llvm.pow.f64(double %x, double %y)
; CHECK: ret double %p
define double @unoptimized(i8* %dst, double %x, double %y) noinline optnone gc "cangjie" {
  call void @llvm.cj.memset(i8* %dst, i8 0, i64 8, i1 false)
  %p = call double @llvm.pow.f64(double %x, double %y)
  ret double %p
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare double @llvm.pow.f64(double, double)
