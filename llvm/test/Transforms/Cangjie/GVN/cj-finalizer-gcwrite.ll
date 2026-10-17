; RUN: opt -gvn --cangjie-pipeline -S < %s | FileCheck %s

target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"

declare i8 addrspace(1)* @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)*)
declare noalias i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)

define i8 addrspace(1)* @registered_store(i8 addrspace(1)* %obj, i8 addrspace(1)* %value) gc "cangjie" {
; CHECK-LABEL: @registered_store(
; CHECK: call void ({{.*}}) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %registered,
; CHECK: ret i8 addrspace(1)* %value
  %registered = call i8 addrspace(1)* @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)* %obj)
  %field = getelementptr i8, i8 addrspace(1)* %registered, i64 8
  %slot = bitcast i8 addrspace(1)* %field to i8 addrspace(1)* addrspace(1)*
  store i8 addrspace(1)* null, i8 addrspace(1)* addrspace(1)* %slot
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %registered, i8 addrspace(1)* addrspace(1)* %slot, i32 1)
  %after = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %slot
  ret i8 addrspace(1)* %after
}

define i8 addrspace(1)* @alloc_store(i8* %ti, i8 addrspace(1)* %value) gc "cangjie" {
; CHECK-LABEL: @alloc_store(
; CHECK: call void ({{.*}}) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %obj,
; CHECK: ret i8 addrspace(1)* %value
  %obj = call noalias i8 addrspace(1)* @CJ_MCC_NewObject(i8* %ti, i32 16)
  %field = getelementptr i8, i8 addrspace(1)* %obj, i64 8
  %slot = bitcast i8 addrspace(1)* %field to i8 addrspace(1)* addrspace(1)*
  store i8 addrspace(1)* null, i8 addrspace(1)* addrspace(1)* %slot
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %obj, i8 addrspace(1)* addrspace(1)* %slot, i32 1)
  %after = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %slot
  ret i8 addrspace(1)* %after
}

define i8 addrspace(1)* @unrelated_store(i8 addrspace(1)* %obj, i8* %ti, i8 addrspace(1)* %value) gc "cangjie" {
; CHECK-LABEL: @unrelated_store(
; CHECK: call void ({{.*}}) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %other,
; CHECK: ret i8 addrspace(1)* null
  %registered = call i8 addrspace(1)* @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)* %obj)
  %other = call noalias i8 addrspace(1)* @CJ_MCC_NewObject(i8* %ti, i32 16)
  %field = getelementptr i8, i8 addrspace(1)* %registered, i64 8
  %slot = bitcast i8 addrspace(1)* %field to i8 addrspace(1)* addrspace(1)*
  %ofield = getelementptr i8, i8 addrspace(1)* %other, i64 8
  %oslot = bitcast i8 addrspace(1)* %ofield to i8 addrspace(1)* addrspace(1)*
  store i8 addrspace(1)* null, i8 addrspace(1)* addrspace(1)* %slot
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %other, i8 addrspace(1)* addrspace(1)* %oslot, i32 1)
  %after = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %slot
  ret i8 addrspace(1)* %after
}
