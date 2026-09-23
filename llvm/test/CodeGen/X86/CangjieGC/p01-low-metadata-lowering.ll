; RUN: llc --cangjie-pipeline -mtriple=x86_64 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; ZGC zAddress.inline.hpp:609-625,734-740; Cangjie $BP distinguishes value storage.

define void @p01_write(i8 addrspace(1)* %value, i8 addrspace(1)* %base,
                      i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
; CHECK-LABEL: define void @p01_write(
; CHECK: %cj.store.inheap.result = phi i1
; CHECK: br i1 %cj.store.inheap.result, label %storeFast, label %storeAccessor
; CHECK: storeFast:
; CHECK: load i16
; CHECK: getelementptr i8, i8* %cj.gcdata{{[0-9]*}}, i64 32
; CHECK: %cj.store.bad = and i64
; CHECK: storeSlow:
; CHECK: call void @CJ_MCC_StoreBarrierOnHeapField
; CHECK: storeFinish:
; CHECK: [[VALUE:%.*]] = call i64 asm "movq $1, $0", "=&r,r"(i8 addrspace(1)* %value)
; CHECK: [[SHIFT:%.*]] = load i64, i64* @g_cjLoadShift
; CHECK: getelementptr i8, i8* %cj.gcdata{{[0-9]*}}, i64 24
; CHECK: [[ADDRESS:%.*]] = shl i64 [[VALUE]], [[SHIFT]]
; CHECK: [[WORD:%.*]] = or i64 [[ADDRESS]], %cj.storegoodmask
; CHECK: store volatile i64 [[WORD]]
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %base,
                                i8 addrspace(1)* addrspace(1)* %slot, i32 1)
  ret void
}
define i8 addrspace(1)* @p01_read(i8 addrspace(1)* %base,
                                 i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
; CHECK-LABEL: define i8 addrspace(1)* @p01_read(
; CHECK: %cj.read.inheap.result = phi i1
; CHECK: br i1 %cj.read.inheap.result, label %loadFast, label %gcMarked
; CHECK: loadFast:
; CHECK: and i64 {{.*}}, %cj.loadbadmask
; CHECK: br i1 {{.*}}, label %gcNoMarked, label %gcMarked
; CHECK: gcNoMarked:
; CHECK-NEXT: [[READSHIFT:%.*]] = load i64, i64* @g_cjLoadShift
; CHECK-NEXT: [[READADDR:%.*]] = lshr i64 {{%.*}}, [[READSHIFT]]
; CHECK-NEXT: [[PLAIN:%.*]] = inttoptr i64 [[READADDR]] to i8 addrspace(1)*
  %value = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %base,
                       i8 addrspace(1)* addrspace(1)* %slot)
  ret i8 addrspace(1)* %value
}
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)
declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
