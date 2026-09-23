; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O0 -verify-machineinstrs -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 -verify-machineinstrs -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
;
; Storage domain must be proved from the final slot, after escape analysis.
target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
; CHECK-LABEL: define i8 addrspace(1)* @probe(
; CHECK-NOT: g_cjHeapRangeCount
; CHECK: cj.loadbadmask
; CHECK-NOT: g_cjHeapRangeCount
; CHECK: ret i8 addrspace(1)*
define i8 addrspace(1)* @probe(i8* %type, i8 addrspace(1)* %arg, i1 %cond, i64 %index) gc "cangjie" personality i32 (...)* @__gxx_personality_v0 {
entry:
  %token = invoke token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i32)* @CJ_MCC_NewObject, i32 2, i32 0, i8* %type, i32 64) to label %normal unwind label %exception
normal:
  %heap = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  ; End allocation dominance while preserving the proven heap domain.
  %allocation.boundary = call token (...) @llvm.cj.gc.statepoint(i64 101, i32 0, void ()* @safepoint, i32 0, i32 0)
  %field = getelementptr inbounds i8, i8 addrspace(1)* %heap, i64 8
  %slot = bitcast i8 addrspace(1)* %field to i8 addrspace(1)* addrspace(1)*
  %value = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %heap, i8 addrspace(1)* addrspace(1)* %slot)
  ret i8 addrspace(1)* %value
exception:
  %exception.value = landingpad { i8*, i32 } cleanup
  resume { i8*, i32 } %exception.value
}

declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare i8 addrspace(1)* @CJ_MCC_NewArray(i8*, i64, i64)
declare i8 addrspace(1)* @unknown_allocator(i8*, i32)
declare i32 @__gxx_personality_v0(...)
declare void @safepoint()
declare i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token, i32 immarg, i32 immarg)
declare token @llvm.cj.gc.statepoint(...)
declare i8 addrspace(1)* @llvm.cj.gc.result(token)
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)
declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
