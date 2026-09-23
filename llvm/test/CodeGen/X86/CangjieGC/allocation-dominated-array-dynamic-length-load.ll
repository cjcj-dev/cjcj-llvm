; RUN: opt -passes=cj-ir-verifier -disable-output < %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O0 -enable-gc-fast-path=false -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 -enable-gc-fast-path=false -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=aarch64 -O2 -enable-gc-fast-path=false -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; ZGC zBarrierSetC2.cpp:498-508; barrierSetC2.cpp:1089-1102.
target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
define i8 addrspace(1)* @probe(i8* %type, i8 addrspace(1)* %value, i64 %index, i64 %length, i1 %again) gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i64)* @CJ_MCC_NewObjArray, i32 2, i32 0, i8* %type, i64 %length)
  %heap = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  %field = getelementptr i8, i8 addrspace(1)* %heap, i64 %index
  %slot = bitcast i8 addrspace(1)* %field to i8 addrspace(1)* addrspace(1)*
; CHECK-LABEL: define i8 addrspace(1)* @probe(
; CHECK: cj.loadbadmask
; CHECK: call i8 addrspace(1)* @CJ_MCC_ReadRefField
; CHECK: ret i8 addrspace(1)*
  %result = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %heap, i8 addrspace(1)* addrspace(1)* %slot)
  ret i8 addrspace(1)* %result
}
declare i8 addrspace(1)* @CJ_MCC_NewObjArray(i8*, i64)
declare token @llvm.cj.gc.statepoint(...)
declare i8 addrspace(1)* @llvm.cj.gc.result(token)
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)
declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
declare void @safepoint()
