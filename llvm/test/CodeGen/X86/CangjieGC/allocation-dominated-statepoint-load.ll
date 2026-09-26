; RUN: opt -passes=cj-ir-verifier -disable-output < %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O0 -enable-gc-fast-path=false -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 -enable-gc-fast-path=false -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=aarch64 -O2 -enable-gc-fast-path=false -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; Retain the barrier and pass the tested load with its original slot.
; ZGC zBarrier.inline.hpp:456-466 (load -> preloaded -> barrier).
; ZGC zBarrierSetC2.cpp:498-508; barrierSetC2.cpp:1089-1102.
target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
define i8 addrspace(1)* @probe(i8* %type, i8 addrspace(1)* %value, i64 %index, i64 %length, i1 %again) gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i64)* @CJ_MCC_NewObject, i32 2, i32 0, i8* %type, i64 64)
  %heap = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  %point = call token (...) @llvm.cj.gc.statepoint(i64 1, i32 0, void ()* @safepoint, i32 0, i32 0)
  %field = getelementptr inbounds i8, i8 addrspace(1)* %heap, i64 8
  %slot = bitcast i8 addrspace(1)* %field to i8 addrspace(1)* addrspace(1)*
; CHECK-LABEL: define i8 addrspace(1)* @probe(
; CHECK: [[LOADED:%[^ ]+]] = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %slot
; CHECK: [[BITS:%[^ ]+]] = ptrtoint i8 addrspace(1)* [[LOADED]] to i64
; CHECK: [[MASK:%cj.loadbadmask[^ ]*]] = load i64
; CHECK: [[BAD:%[^ ]+]] = and i64 [[BITS]], [[MASK]]
; CHECK: [[GOOD:%[^ ]+]] = icmp eq i64 [[BAD]], 0
; CHECK: br i1 [[GOOD]], label %gcNoMarked, label %gcMarked
; CHECK: gcMarked:
; CHECK: [[SLOW:%[^ ]+]] = call i8 addrspace(1)* @CJ_MCC_LoadBarrierOnOopFieldPreloaded(i8 addrspace(1)* [[LOADED]], i8 addrspace(1)* addrspace(1)* %slot)
; CHECK: loadFinish:
; CHECK: [[RESULT:%[^ ]+]] = phi i8 addrspace(1)* {{.*}}[ [[SLOW]], %gcMarked ]
; CHECK: ret i8 addrspace(1)* [[RESULT]]
  %result = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %heap, i8 addrspace(1)* addrspace(1)* %slot)
  ret i8 addrspace(1)* %result
}
declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i64)
declare token @llvm.cj.gc.statepoint(...)
declare i8 addrspace(1)* @llvm.cj.gc.result(token)
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)
declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
declare void @safepoint()
