; RUN: opt -mtriple=x86_64-unknown-linux-gnu -passes=cj-runtime-lowering %s -o %t.bc
; RUN: llc -cangjie-pipeline -verify-machineinstrs %t.bc -o - | FileCheck %s
; RUN: opt -mtriple=x86_64-unknown-linux-musl -passes=cj-runtime-lowering -S %s | FileCheck %s --check-prefix=OTHER
; RUN: opt -mtriple=x86_64-unknown-linux-gnux32 -passes=cj-runtime-lowering -S %s | FileCheck %s --check-prefix=OTHER
; RUN: opt -mtriple=aarch64-unknown-linux-gnu -passes=cj-runtime-lowering -S %s | FileCheck %s --check-prefix=OTHER
; OTHER-NOT: CJ_MCC_C2NStubNoFP
;
; Qualification uses the actual call type and preservation mask, including a
; deliberately inconsistent opaque-pointer prototype and an escaped address.

declare ptr @LLVMBuildNeg(ptr, ptr, ptr) "cj2c"
declare ptr @LLVMBuildFNeg(ptr, ptr, ptr) "cj2c"
declare ptr @LLVMConstReal(ptr, double) "cj2c"
declare i64 @six(i64,i64,i64,i64,i64,i64) "cj2c"
declare i64 @seven(i64,i64,i64,i64,i64,i64,i64) "cj2c"
declare i64 @variadic(i64,...) "cj2c"
declare i64 @inconsistent(i64) "cj2c"
declare i64 @escaped(i64) "cj2c"
declare i64 @special(i64 inreg) "cj2c"
declare preserve_allcc i64 @preserved(i64) "cj2c"
@escaped_address = global ptr @escaped

; CHECK-LABEL: neg:
; CHECK: callq CJ_MCC_C2NStubNoFP
; CHECK-LABEL: fneg:
; CHECK: callq CJ_MCC_C2NStubNoFP
; CHECK-LABEL: real:
; CHECK: callq CJ_MCC_C2NStub{{(@PLT)?$}}
; CHECK-LABEL: six_args:
; CHECK: callq CJ_MCC_C2NStubNoFP
; CHECK-LABEL: stack_args:
; CHECK: callq CJ_MCC_C2NStub{{(@PLT)?$}}
; CHECK-LABEL: varargs:
; CHECK: callq CJ_MCC_C2NStub{{(@PLT)?$}}
; CHECK-LABEL: mismatch:
; CHECK: callq CJ_MCC_C2NStub{{(@PLT)?$}}
; CHECK-LABEL: address_escaped:
; CHECK: callq CJ_MCC_C2NStub{{(@PLT)?$}}
; CHECK-LABEL: special_attr:
; CHECK: callq CJ_MCC_C2NStub{{(@PLT)?$}}
; CHECK-LABEL: preserved_xmm:
; CHECK: callq CJ_MCC_C2NStub{{(@PLT)?$}}
; CHECK-LABEL: live_fp:
; CHECK: movsd %xmm0, {{.*}}(%{{(rsp|rbp)}})
; CHECK: callq CJ_MCC_C2NStubNoFP
; CHECK: {{(movsd|addsd)}} {{.*}}(%{{(rsp|rbp)}}), %xmm{{[0-9]+}}

define ptr @neg(ptr %a,ptr %b,ptr %c) gc "cangjie" {
 %r=call ptr @LLVMBuildNeg(ptr %a,ptr %b,ptr %c)
 ret ptr %r
}
define ptr @fneg(ptr %a,ptr %b,ptr %c) gc "cangjie" {
 %r=call ptr @LLVMBuildFNeg(ptr %a,ptr %b,ptr %c)
 ret ptr %r
}
define ptr @real(ptr %a,double %b) gc "cangjie" {
 %r=call ptr @LLVMConstReal(ptr %a,double %b)
 ret ptr %r
}
define i64 @six_args() gc "cangjie" {
 %r=call i64 @six(i64 1,i64 2,i64 3,i64 4,i64 5,i64 6)
 ret i64 %r
}
define i64 @stack_args() gc "cangjie" {
 %r=call i64 @seven(i64 1,i64 2,i64 3,i64 4,i64 5,i64 6,i64 7)
 ret i64 %r
}
define i64 @varargs() gc "cangjie" {
 %r=call i64 (i64,...) @variadic(i64 1,i64 2)
 ret i64 %r
}
define i64 @mismatch(double %x) gc "cangjie" {
 %r=call i64 (double) @inconsistent(double %x)
 ret i64 %r
}
define i64 @address_escaped(i64 %x) gc "cangjie" {
 %r=call i64 @escaped(i64 %x)
 ret i64 %r
}
define i64 @special_attr(i64 %x) gc "cangjie" {
 %r=call i64 @special(i64 inreg %x)
 ret i64 %r
}
define i64 @preserved_xmm(i64 %x) gc "cangjie" {
 %r=call preserve_allcc i64 @preserved(i64 %x)
 ret i64 %r
}
define double @live_fp(double %x) gc "cangjie" {
 %r=call i64 @six(i64 1,i64 2,i64 3,i64 4,i64 5,i64 6)
 %f=sitofp i64 %r to double
 %sum=fadd double %x,%f
 ret double %sum
}
