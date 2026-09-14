; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O0 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s --implicit-check-not=gcNoRunning
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s --implicit-check-not=gcNoRunning
; A static slot is represented by the null-base atomic ABI. Preserve order
; operands and returned values while routing through the runtime barriers.
; ZGC zBarrierSet.inline.hpp:598,611 colours native atomic operands.

; CHECK-LABEL: define void @static_atomic_store(
; CHECK: call void @CJ_MCC_AtomicWriteReference(i8 addrspace(1)* %value, i8 addrspace(1)* null, i8 addrspace(1)* addrspace(1)* %slot, i32 %order)
; CHECK-NEXT: ret void
define void @static_atomic_store(i8 addrspace(1)* %value, i8 addrspace(1)* addrspace(1)* %slot, i32 %order) gc "cangjie" {
  call void @llvm.cj.atomic.store(i8 addrspace(1)* %value, i8 addrspace(1)* null, i8 addrspace(1)* addrspace(1)* %slot, i32 %order)
  ret void
}

; CHECK-LABEL: define i8 addrspace(1)* @static_atomic_swap(
; CHECK: [[RESULT:%.*]] = call i8 addrspace(1)* @CJ_MCC_AtomicSwapReference(i8 addrspace(1)* %value, i8 addrspace(1)* null, i8 addrspace(1)* addrspace(1)* %slot, i32 %order)
; CHECK-NEXT: ret i8 addrspace(1)* [[RESULT]]
define i8 addrspace(1)* @static_atomic_swap(i8 addrspace(1)* %value, i8 addrspace(1)* addrspace(1)* %slot, i32 %order) gc "cangjie" {
  %result = call i8 addrspace(1)* @llvm.cj.atomic.swap(i8 addrspace(1)* %value, i8 addrspace(1)* null, i8 addrspace(1)* addrspace(1)* %slot, i32 %order)
  ret i8 addrspace(1)* %result
}

; CHECK-LABEL: define i1 @static_atomic_compare_swap(
; CHECK: [[RESULT:%.*]] = call i1 @CJ_MCC_AtomicCompareAndSwapReference(i8 addrspace(1)* %expected, i8 addrspace(1)* %value, i8 addrspace(1)* null, i8 addrspace(1)* addrspace(1)* %slot, i32 %success, i32 %failure)
; CHECK-NEXT: ret i1 [[RESULT]]
define i1 @static_atomic_compare_swap(i8 addrspace(1)* %value, i8 addrspace(1)* addrspace(1)* %slot, i8 addrspace(1)* %expected, i32 %success, i32 %failure) gc "cangjie" {
  %result = call i1 @llvm.cj.atomic.compare.swap(i8 addrspace(1)* %expected, i8 addrspace(1)* %value, i8 addrspace(1)* null, i8 addrspace(1)* addrspace(1)* %slot, i32 %success, i32 %failure)
  ret i1 %result
}

declare void @llvm.cj.atomic.store(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, i32)
declare i8 addrspace(1)* @llvm.cj.atomic.swap(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, i32)
declare i1 @llvm.cj.atomic.compare.swap(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, i32, i32)
