; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O0 -print-after=cj-rewrite-statepoint -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 -print-after=cj-rewrite-statepoint -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=aarch64 -O2 -print-after=cj-rewrite-statepoint -o /dev/null < %s 2>&1 | FileCheck %s
; The array remains live until Release. The Acquire return point must carry it.
; A leaf Release is a control: changing Acquire must not add a Release statepoint.
target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
define void @rawdata_pair(i8 addrspace(1)* %array, i8* %isCopy) gc "cangjie" {
; CHECK-LABEL: define void @rawdata_pair(
; CHECK: [[TOKEN:%[^ ]+]] = call token (...) @llvm.cj.gc.statepoint{{.*}}@CJ_MCC_AcquireRawData{{.*}}[ "gc-live"(i8 addrspace(1)* %array) ]
; CHECK: [[RELOC:%[^ ]+]] = call coldcc i8 addrspace(1)* @llvm.cj.gc.relocate{{.*}}(token [[TOKEN]], i32 0, i32 0)
; CHECK: call void @CJ_MCC_ReleaseRawData(i8 addrspace(1)* [[RELOC]],
  %raw = call i8* @llvm.cj.acquire.rawdata(i8 addrspace(1)* %array, i8* %isCopy)
  call void @llvm.cj.release.rawdata(i8 addrspace(1)* %array, i8* %raw, i32 0)
  ret void
}
declare i8* @llvm.cj.acquire.rawdata(i8 addrspace(1)*, i8*)
declare void @llvm.cj.release.rawdata(i8 addrspace(1)*, i8*, i32)
