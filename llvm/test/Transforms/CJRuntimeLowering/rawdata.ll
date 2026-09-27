; RUN: opt < %s -passes=cj-runtime-lowering -S | FileCheck %s
; Acquire may wait in ZJNICritical::enter_inner; Release only exits critical.
; HotSpot sharedRuntime_x86_64.cpp:2365-2372; zJNICritical.cpp:100-128.

declare i8* @llvm.cj.acquire.rawdata(i8 addrspace(1)*, i8*)
declare void @llvm.cj.release.rawdata(i8 addrspace(1)*, i8*, i32)

define void @rawdata_pair(i8 addrspace(1)* %array, i8* %isCopy) gc "cangjie" {
; CHECK-LABEL: define void @rawdata_pair(
; CHECK: %raw = call i8* @CJ_MCC_AcquireRawData(i8 addrspace(1)* %array, i8* %isCopy)
; CHECK: call void @CJ_MCC_ReleaseRawData(i8 addrspace(1)* %array, i8* %raw, i32 0)
  %raw = call i8* @llvm.cj.acquire.rawdata(i8 addrspace(1)* %array, i8* %isCopy)
  call void @llvm.cj.release.rawdata(i8 addrspace(1)* %array, i8* %raw, i32 0)
  ret void
}
; CHECK: declare i8* @CJ_MCC_AcquireRawData(i8 addrspace(1)*, i8*) [[ACQUIRE:#[0-9]+]]
; CHECK: declare void @CJ_MCC_ReleaseRawData(i8 addrspace(1)*, i8*, i32) [[RELEASE:#[0-9]+]]
; CHECK-DAG: attributes [[ACQUIRE]] = { nounwind "cj-runtime" }
; CHECK-DAG: attributes [[RELEASE]] = { nounwind "cj-runtime" "gc-leaf-function" }
