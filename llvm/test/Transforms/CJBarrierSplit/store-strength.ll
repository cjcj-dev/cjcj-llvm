; RUN: opt -passes=cj-barrier-split,verify -S < %s | FileCheck %s
; RUN: opt -cj-barrier-split -S < %s | FileCheck %s
; RUN: opt -passes=cj-barrier-split -S < %s -o %t
; RUN: llc --cangjie-pipeline -mtriple=x86_64 %t -o - | FileCheck %s --check-prefix=ASM

; A value record can begin inside a class. Its first word is payload, not an
; object header. Splitting its aggregate store must preserve known strength.
; ZGC zBarrierSet.inline.hpp:232-242, jni.cpp:1928.
target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
%Record = type { i64, i8 addrspace(1)* }

declare void @llvm.cj.gcwrite.struct.p0i8.i64(i8 addrspace(1)*, i8 addrspace(1)*, i8*, i64)
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)

; ASM-LABEL: record_store:
; ASM: CJ_MCC_WriteRefField_Strong
; ASM-NOT: CJ_MCC_WriteRefField@PLT
; CHECK-LABEL: define void @record_store(
; CHECK: call void {{.*}}@llvm.cj.gcwrite.ref({{.*}}, i32 1)
; CHECK-NOT: call void {{.*}}@llvm.cj.gcwrite.struct
; CHECK: ret void
define void @record_store(i8 addrspace(1)* %interior, %Record* %source) gc "cangjie" {
  %typed = bitcast i8 addrspace(1)* %interior to %Record addrspace(1)*
  %dst = bitcast %Record addrspace(1)* %typed to i8 addrspace(1)*
  %src = bitcast %Record* %source to i8*
  call void @llvm.cj.gcwrite.struct.p0i8.i64(i8 addrspace(1)* %interior, i8 addrspace(1)* %dst, i8* %src, i64 16)
  ret void
}

; An actual unknown oop slot must retain its runtime classification.
; ASM-LABEL: unknown_store:
; ASM-NOT: CJ_MCC_WriteRefField_Strong
; ASM: CJ_MCC_WriteRefField@PLT
; CHECK-LABEL: define void @unknown_store(
; CHECK: call void {{.*}}@llvm.cj.gcwrite.ref({{.*}}, i32 0)
; CHECK: ret void
define void @unknown_store(i8 addrspace(1)* %object, i8 addrspace(1)* addrspace(1)* %slot, i8 addrspace(1)* %value) gc "cangjie" {
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %object, i8 addrspace(1)* addrspace(1)* %slot, i32 0)
  ret void
}
