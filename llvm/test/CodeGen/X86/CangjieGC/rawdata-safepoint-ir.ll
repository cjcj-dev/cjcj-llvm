; RUN: opt --cangjie-pipeline -O0 -mtriple=x86_64 -S < %s -o %t.o0.ll
; RUN: FileCheck %s < %t.o0.ll
; RUN: opt --cangjie-pipeline -O2 -mtriple=x86_64 -S < %s -o %t.o2.ll
; RUN: FileCheck %s < %t.o2.ll
; RUN: opt --cangjie-pipeline -O2 -mtriple=aarch64 -S < %s -o %t.arm.ll
; RUN: FileCheck %s < %t.arm.ll
; The array stays live until Release, so the statepoint at Acquire must publish
; it and the value forwarded to Release must be the relocated one. A leaf
; Release is a control: changing Acquire must not add a Release statepoint.
; HotSpot sharedRuntime_x86_64.cpp:2370 publishes the native oop map at the
; JNI critical call; the Cangjie half is the gc-live operand plus the relocate.
target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
define void @rawdata_pair(i8 addrspace(1)* %array, i8* %isCopy) gc "cangjie" {
; CHECK-LABEL: define void @rawdata_pair(
; CHECK: [[TOKEN:%[^ ]+]] = {{(tail )?}}call token (...) @llvm.cj.gc.statepoint{{.*}}@CJ_MCC_AcquireRawData{{.*}}[ "gc-live"(i8 addrspace(1)* %array) ]
; CHECK: [[RELOC:%[^ ]+]] = call coldcc i8 addrspace(1)* @llvm.cj.gc.relocate{{.*}}(token [[TOKEN]], i32 0, i32 0)
; CHECK: call void @CJ_MCC_ReleaseRawData(i8 addrspace(1)* [[RELOC]],
  %raw = call i8* @llvm.cj.acquire.rawdata(i8 addrspace(1)* %array, i8* %isCopy)
  call void @llvm.cj.release.rawdata(i8 addrspace(1)* %array, i8* %raw, i32 0)
  ret void
}
declare i8* @llvm.cj.acquire.rawdata(i8 addrspace(1)*, i8*)
declare void @llvm.cj.release.rawdata(i8 addrspace(1)*, i8*, i32)
