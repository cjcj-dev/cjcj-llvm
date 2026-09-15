; RUN: llc --cangjie-pipeline -mtriple=x86_64 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; ZGC zAddress.inline.hpp:609-625,734-740; Cangjie $BP distinguishes value storage.

define void @p01_write(i8 addrspace(1)* %value, i8 addrspace(1)* %base,
                      i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
; CHECK-LABEL: define void @p01_write(
; CHECK: [[PREV:%.*]] = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %slot
; CHECK: [[PREVI:%.*]] = ptrtoint i8 addrspace(1)* [[PREV]] to i64
; CHECK: [[MASK:%.*]] = load i64, i64* @g_cjStoreBadMask
; CHECK: [[BAD:%.*]] = and i64 [[PREVI]], [[MASK]]
; CHECK: [[COLOROK:%.*]] = icmp eq i64 [[BAD]], 0
; CHECK: [[BASE:%.*]] = ptrtoint i8 addrspace(1)* %base to i64
; CHECK: [[HEAP:%.*]] = icmp ugt i64 [[BASE]], 1
; CHECK: [[FAST:%.*]] = and i1 [[COLOROK]], [[HEAP]]
; CHECK: br i1 [[FAST]], label %storeFinish, label %gcStoreBad
; CHECK: storeFinish:
; CHECK: [[VALUE:%.*]] = call i64 asm "movq $1, $0", "=&r,r"(i8 addrspace(1)* %value)
; CHECK: [[SHIFT:%.*]] = load i64, i64* @g_cjLoadShift
; CHECK: [[ADDRESS:%.*]] = shl i64 [[VALUE]], [[SHIFT]]
; CHECK: [[GOOD:%.*]] = load i64, i64* @g_cjStoreGoodMask
; CHECK: [[WORD:%.*]] = or i64 [[ADDRESS]], [[GOOD]]
; CHECK: store volatile i64 [[WORD]]
; CHECK-NEXT: call void @CJ_MCC_PostWriteRefField
; CHECK: gcStoreBad:
; CHECK: call void @CJ_MCC_WriteRefField
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %base,
                                i8 addrspace(1)* addrspace(1)* %slot)
  ret void
}
define i8 addrspace(1)* @p01_read(i8 addrspace(1)* %base,
                                 i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
; CHECK-LABEL: define i8 addrspace(1)* @p01_read(
; CHECK: [[READBASE:%.*]] = ptrtoint i8 addrspace(1)* %base to i64
; CHECK: [[READHEAP:%.*]] = icmp ugt i64 [[READBASE]], 1
; CHECK: [[READFAST:%.*]] = and i1 {{%.*}}, [[READHEAP]]
; CHECK: br i1 [[READFAST]], label %gcNoMarked, label %gcMarked
; CHECK: gcNoMarked:
; CHECK-NEXT: [[READSHIFT:%.*]] = load i64, i64* @g_cjLoadShift
; CHECK-NEXT: [[READADDR:%.*]] = lshr i64 {{%.*}}, [[READSHIFT]]
; CHECK-NEXT: [[PLAIN:%.*]] = inttoptr i64 [[READADDR]] to i8 addrspace(1)*
  %value = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %base,
                       i8 addrspace(1)* addrspace(1)* %slot)
  ret i8 addrspace(1)* %value
}
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
