; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O0 -enable-gc-fast-path=false -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 -enable-gc-fast-path=false -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; Check the product IR delivered to barrier lowering, then finish real ISel.
; Callee replacement must preserve the exact buffer, byte, length and volatility.
; It is legalization even for optnone, not the full CJSpecificOpt optimizer.
target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
%Plain = type { i8 addrspace(1)* }

; CHECK-LABEL: define void @stack_init()
; CHECK: %plain = alloca %Plain
; CHECK: %init = bitcast %Plain* %plain to i8*
; CHECK: call void @llvm.memset.p0i8.i64(i8* %init, i8 0, i64 8, i1 false)
; CHECK: ret void
; The otherwise unused alloca remains: llc did not run deadAllocaElimination.
define void @stack_init() gc "cangjie" {
  %plain = alloca %Plain
  %init = bitcast %Plain* %plain to i8*
  call void @llvm.cj.memset(i8* %init, i8 0, i64 8, i1 false)
  ret void
}

; CHECK-LABEL: define void @dynamic_init(
; CHECK: call void @llvm.memset.p0i8.i64(i8* %dst, i8 %byte, i64 %size, i1 true)
; CHECK: ret void
define void @dynamic_init(i8* %dst, i8 %byte, i64 %size) noinline optnone gc "cangjie" {
  call void @llvm.cj.memset(i8* %dst, i8 %byte, i64 %size, i1 true)
  ret void
}

; CHECK-LABEL: define double @keep_pow(
; CHECK: %p = call double @llvm.pow.f64(double %x, double %y)
; CHECK: ret double %p
define double @keep_pow(double %x, double %y) gc "cangjie" {
  %p = call double @llvm.pow.f64(double %x, double %y)
  ret double %p
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare double @llvm.pow.f64(double, double)
