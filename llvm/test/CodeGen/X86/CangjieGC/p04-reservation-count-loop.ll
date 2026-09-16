; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O0 -verify-machineinstrs -print-module-scope -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 -verify-machineinstrs -print-module-scope -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
;
; P01 slot-domain ABI extension for P04 ZGC reservations. The runtime owns up
; to ZMaxVirtualReservations=100 disjoint ranges. Zero count must not read an
; entry, the index is bounded by the live count, and bad counts must not index
; outside either provider array. Read and write retain their original gates.
;
; CHECK-DAG: @g_cjHeapRangeStart = external global [100 x i64]
; CHECK-DAG: @g_cjHeapRangeEnd = external global [100 x i64]
;
; CHECK-LABEL: define void @p04_write(
; CHECK: %cj.store.inheap.n = load i64, i64* @g_cjHeapRangeCount
; CHECK: %cj.store.inheap.count.valid = icmp ule i64 %cj.store.inheap.n, 100
; CHECK: br i1 %cj.store.inheap.count.valid, label %cj.store.inheap.check, label %cj.store.inheap.invalid
; CHECK: cj.store.inheap.check:
; CHECK: icmp ne i64 %cj.store.inheap.n, 0
; CHECK: cj.store.inheap.loop:
; CHECK: %cj.store.inheap.index = phi i64
; CHECK: getelementptr inbounds [100 x i64], [100 x i64]* @g_cjHeapRangeStart, i64 0, i64 %cj.store.inheap.index
; CHECK: getelementptr inbounds [100 x i64], [100 x i64]* @g_cjHeapRangeEnd, i64 0, i64 %cj.store.inheap.index
; CHECK: icmp uge i64 %cj.store.place.i, %cj.store.inheap.start
; CHECK: icmp ult i64 %cj.store.place.i, %cj.store.inheap.end
; CHECK: cj.store.inheap.next:
; CHECK: icmp ult i64 %cj.store.inheap.next.index, %cj.store.inheap.n
; CHECK: cj.store.inheap.invalid:
; CHECK: call void @llvm.trap()
; CHECK: unreachable
; CHECK: cj.store.inheap.done:
; CHECK: %cj.store.inheap.result = phi i1
; CHECK: %cj.store.heap.slot = and i1 %cj.store.heap.fast, %cj.store.inheap.result
; CHECK: br i1 %cj.store.heap.slot, label %storeFinish, label %gcStoreBad
; CHECK-NOT: call void @CJ_MCC_PostWriteRefField
; CHECK: call void @CJ_MCC_WriteRefField

define void @p04_write(i8 addrspace(1)* %value, i8 addrspace(1)* %base,
                      i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %base,
                                i8 addrspace(1)* addrspace(1)* %slot)
  ret void
}

; CHECK-LABEL: define i8 addrspace(1)* @p04_read(
; CHECK: %cj.read.inheap.n = load i64, i64* @g_cjHeapRangeCount
; CHECK: %cj.read.inheap.count.valid = icmp ule i64 %cj.read.inheap.n, 100
; CHECK: cj.read.inheap.check:
; CHECK: icmp ne i64 %cj.read.inheap.n, 0
; CHECK: cj.read.inheap.loop:
; CHECK: %cj.read.inheap.index = phi i64
; CHECK: getelementptr inbounds [100 x i64], [100 x i64]* @g_cjHeapRangeStart, i64 0, i64 %cj.read.inheap.index
; CHECK: getelementptr inbounds [100 x i64], [100 x i64]* @g_cjHeapRangeEnd, i64 0, i64 %cj.read.inheap.index
; CHECK: cj.read.inheap.next:
; CHECK: icmp ult i64 %cj.read.inheap.next.index, %cj.read.inheap.n
; CHECK: cj.read.inheap.invalid:
; CHECK: call void @llvm.trap()
; CHECK: unreachable
; CHECK: cj.read.inheap.done:
; CHECK: %cj.read.inheap.result = phi i1
; CHECK: %cj.read.heap.slot = and i1 %cj.read.heap.fast, %cj.read.inheap.result
; CHECK: br i1 %cj.read.heap.slot, label %gcNoMarked, label %gcMarked

define i8 addrspace(1)* @p04_read(i8 addrspace(1)* %base,
                                 i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
  %value = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %base,
                       i8 addrspace(1)* addrspace(1)* %slot)
  ret i8 addrspace(1)* %value
}

declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
