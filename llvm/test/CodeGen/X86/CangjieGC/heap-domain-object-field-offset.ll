; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O0 -verify-machineinstrs -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 -verify-machineinstrs -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
;
; A constant field offset below the MCC_NewObject size operand addresses the
; allocated object even without inbounds, so the reserved-range test is
; folded. The barrier itself is kept: dominance elision stays inbounds-only.
target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"

; CHECK-LABEL: define void @fresh_write(
; CHECK-NOT: g_cjHeapRangeCount
; CHECK: cj.storebadmask
; CHECK-NOT: g_cjHeapRangeCount
; CHECK: ret void
define void @fresh_write(i8* %type, i8 addrspace(1)* %value) gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i32)* @CJ_MCC_NewObject, i32 2, i32 0, i8* %type, i32 32)
  %heap = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  %field = getelementptr i8, i8 addrspace(1)* %heap, i64 8
  %slot = bitcast i8 addrspace(1)* %field to i8 addrspace(1)* addrspace(1)*
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %heap, i8 addrspace(1)* addrspace(1)* %slot, i32 1)
  ret void
}

; Relocated copies merged by a phi, and a chained field offset 8 + 16 < 32.
; CHECK-LABEL: define i8 addrspace(1)* @relocated_phi_read(
; CHECK-NOT: g_cjHeapRangeCount
; CHECK: cj.loadbadmask
; CHECK-NOT: g_cjHeapRangeCount
; CHECK: ret i8 addrspace(1)*
define i8 addrspace(1)* @relocated_phi_read(i8* %type, i1 %cond) gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i32)* @CJ_MCC_NewObject, i32 2, i32 0, i8* %type, i32 32)
  %heap = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  br i1 %cond, label %left, label %right
left:
  %sp.left = call token (...) @llvm.cj.gc.statepoint(i64 1, i32 0, void ()* @safepoint, i32 0, i32 0) [ "gc-live"(i8 addrspace(1)* %heap, i8 addrspace(1)* %heap) ]
  %heap.left = call i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token %sp.left, i32 0, i32 1)
  br label %join
right:
  %sp.right = call token (...) @llvm.cj.gc.statepoint(i64 2, i32 0, void ()* @safepoint, i32 0, i32 0) [ "gc-live"(i8 addrspace(1)* %heap, i8 addrspace(1)* %heap) ]
  %heap.right = call i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token %sp.right, i32 0, i32 1)
  br label %join
join:
  %merged = phi i8 addrspace(1)* [ %heap.left, %left ], [ %heap.right, %right ]
  %payload = getelementptr i8, i8 addrspace(1)* %merged, i64 8
  %words = bitcast i8 addrspace(1)* %payload to i64 addrspace(1)*
  %field = getelementptr i64, i64 addrspace(1)* %words, i64 2
  %slot = bitcast i64 addrspace(1)* %field to i8 addrspace(1)* addrspace(1)*
  %value = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %merged, i8 addrspace(1)* addrspace(1)* %slot)
  ret i8 addrspace(1)* %value
}

declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare void @safepoint()
declare i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token, i32 immarg, i32 immarg)
declare token @llvm.cj.gc.statepoint(...)
declare i8 addrspace(1)* @llvm.cj.gc.result(token)
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)
declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
