; RUN: opt --cangjie-pipeline -O0 -mtriple=x86_64 -S < %s -o %t.o0.ll
; RUN: FileCheck %s < %t.o0.ll
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O0 -filetype=obj %t.o0.ll -o %t.o0.o
; RUN: %python %S/Inputs/rawdata-stackmap.py %t.o0.o rawdata_pair
; RUN: opt --cangjie-pipeline -O2 -mtriple=x86_64 -S < %s -o %t.o2.ll
; RUN: FileCheck %s < %t.o2.ll
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 -filetype=obj %t.o2.ll -o %t.o2.o
; RUN: %python %S/Inputs/rawdata-stackmap.py %t.o2.o rawdata_pair
; RUN: opt --cangjie-pipeline -O2 -mtriple=aarch64 -S < %s -o %t.arm.ll
; RUN: FileCheck %s < %t.arm.ll
; RUN: llc --cangjie-pipeline -mtriple=aarch64 -O2 %t.arm.ll -o /dev/null
; The array remains live until Release. The Acquire return point must carry it.
; A leaf Release is a control: changing Acquire must not add a Release statepoint.
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
