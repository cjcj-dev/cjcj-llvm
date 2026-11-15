; RUN: opt -mtriple=x86_64-unknown-linux-gnu -passes="cj-runtime-lowering,cj-rewrite-statepoint" %s -o %t.bc
; RUN: llvm-dis %t.bc -o - | FileCheck %s --check-prefix=SP
; RUN: llc -cangjie-pipeline -verify-machineinstrs %t.bc -o - | FileCheck %s
; The real cjcj producer explicitly disables opaque pointers (LLVM.cj).
; Keep the opaque-pointer direct-call negative cases in cangjie-c2n-nofp.ll.

declare i8* @LLVMBuildNeg(i8*,i8*,i8*) "cj2c"
declare i8* @LLVMBuildFNeg(i8*,i8*,i8*) "cj2c"
declare i8* @LLVMConstReal(i8*,double) "cj2c"
declare i64 @six(i64,i64,i64,i64,i64,i64) "cj2c"
declare i64 @special(i64 inreg) "cj2c"
; SP: call token {{.*}}@llvm.cj.gc.statepoint{{.*}}@LLVMBuildNeg
; SP: call token {{.*}}@llvm.cj.gc.statepoint{{.*}}@LLVMBuildFNeg
; SP: call token {{.*}}@llvm.cj.gc.statepoint{{.*}}@LLVMConstReal
; CHECK-LABEL: neg:
; CHECK: callq CJ_MCC_C2NStubNoFP
; CHECK-LABEL: fneg:
; CHECK: callq CJ_MCC_C2NStubNoFP
; CHECK-LABEL: real:
; CHECK: callq CJ_MCC_C2NStub{{(@PLT)?$}}
; CHECK-LABEL: special_attr:
; CHECK: callq CJ_MCC_C2NStub{{(@PLT)?$}}
; CHECK-LABEL: live_fp:
; CHECK: movsd %xmm0, {{.*}}(%{{(rsp|rbp)}})
; CHECK: callq CJ_MCC_C2NStubNoFP
; CHECK: {{(movsd|addsd)}} {{.*}}(%{{(rsp|rbp)}}), %xmm{{[0-9]+}}
define i8* @neg(i8* %a,i8* %b,i8* %c) gc "cangjie" {
 %r=call i8* @LLVMBuildNeg(i8* %a,i8* %b,i8* %c)
 ret i8* %r
}
define i8* @fneg(i8* %a,i8* %b,i8* %c) gc "cangjie" {
 %r=call i8* @LLVMBuildFNeg(i8* %a,i8* %b,i8* %c)
 ret i8* %r
}
define i8* @real(i8* %a,double %b) gc "cangjie" {
 %r=call i8* @LLVMConstReal(i8* %a,double %b)
 ret i8* %r
}
define i64 @special_attr(i64 %x) gc "cangjie" {
 %r=call i64 @special(i64 inreg %x)
 ret i64 %r
}
define double @live_fp(double %x) gc "cangjie" {
 %r=call i64 @six(i64 1,i64 2,i64 3,i64 4,i64 5,i64 6)
 %f=sitofp i64 %r to double
 %sum=fadd double %x,%f
 ret double %sum
}
