; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O0 -verify-machineinstrs -print-module-scope -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 -verify-machineinstrs -print-module-scope -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
;
; P01 slot-domain ABI extension for P04 ZGC reservations. The runtime owns up
; to ZMaxVirtualReservations=100 disjoint ranges and clears every entry before
; publishing (zAddress.cpp PublishCompilerHeapRanges), so entries at or beyond
; the live count are the empty range [0, 0). Entry 0 is tested inline without
; the count; only a miss loads the count, keeps the capacity trap and scans the
; remaining live entries 1..count-1. Each decision branches directly to the
; heap or accessor path; no boolean result is rematerialized.
;
; CHECK-DAG: @g_cjHeapRangeCount = external global i64
; CHECK-DAG: @g_cjHeapRangeStart = external global [100 x i64]
; CHECK-DAG: @g_cjHeapRangeEnd = external global [100 x i64]
;
; CHECK-LABEL: define void @p04_write(
; CHECK: %cj.store.inheap.first.start = load i64, i64* getelementptr inbounds ([100 x i64], [100 x i64]* @g_cjHeapRangeStart, i64 0, i64 0)
; CHECK: %cj.store.inheap.first.end = load i64, i64* getelementptr inbounds ([100 x i64], [100 x i64]* @g_cjHeapRangeEnd, i64 0, i64 0)
; CHECK: icmp uge i64 {{%.*}}, %cj.store.inheap.first.start
; CHECK: icmp ult i64 {{%.*}}, %cj.store.inheap.first.end
; CHECK: br i1 %cj.store.inheap.first.hit, label %storeFast, label %cj.store.inheap.scan, !prof
; CHECK: cj.store.inheap.scan:
; CHECK: %cj.store.inheap.n = load i64, i64* @g_cjHeapRangeCount
; CHECK: %cj.store.inheap.count.valid = icmp ule i64 %cj.store.inheap.n, 100
; CHECK: br i1 %cj.store.inheap.count.valid, label %cj.store.inheap.check, label %cj.store.inheap.invalid
; CHECK: cj.store.inheap.check:
; CHECK: [[MORE:%.*]] = icmp ugt i64 %cj.store.inheap.n, 1
; CHECK: br i1 [[MORE]], label %cj.store.inheap.loop, label %storeAccessor
; CHECK: cj.store.inheap.loop:
; CHECK: %cj.store.inheap.index = phi i64 [ 1, %cj.store.inheap.check ], [ %cj.store.inheap.next.index, %cj.store.inheap.next ]
; CHECK: getelementptr inbounds [100 x i64], [100 x i64]* @g_cjHeapRangeStart, i64 0, i64 %cj.store.inheap.index
; CHECK: getelementptr inbounds [100 x i64], [100 x i64]* @g_cjHeapRangeEnd, i64 0, i64 %cj.store.inheap.index
; CHECK: icmp uge i64 {{%.*}}, %cj.store.inheap.start
; CHECK: icmp ult i64 {{%.*}}, %cj.store.inheap.end
; CHECK: br i1 %cj.store.inheap.hit, label %storeFast, label %cj.store.inheap.next
; CHECK: cj.store.inheap.next:
; CHECK: [[LIVE:%.*]] = icmp ult i64 %cj.store.inheap.next.index, %cj.store.inheap.n
; CHECK: br i1 [[LIVE]], label %cj.store.inheap.loop, label %storeAccessor
; CHECK: cj.store.inheap.invalid:
; CHECK: call void @llvm.trap()
; CHECK: unreachable
; CHECK-NOT: cj.store.inheap.result
; CHECK-NOT: cj.store.inheap.done
; CHECK: storeAccessor:
; CHECK: call void @CJ_MCC_WriteRefField_Strong
; CHECK: storeFast:
; CHECK-NOT: call void @CJ_MCC_PostWriteRefField

define void @p04_write(i8 addrspace(1)* %value, i8 addrspace(1)* %base,
                      i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %base,
                                i8 addrspace(1)* addrspace(1)* %slot, i32 1)
  ret void
}

; CHECK-LABEL: define i8 addrspace(1)* @p04_read(
; CHECK: %cj.read.inheap.first.start = load i64, i64* getelementptr inbounds ([100 x i64], [100 x i64]* @g_cjHeapRangeStart, i64 0, i64 0)
; CHECK: %cj.read.inheap.first.end = load i64, i64* getelementptr inbounds ([100 x i64], [100 x i64]* @g_cjHeapRangeEnd, i64 0, i64 0)
; CHECK: icmp uge i64 {{%.*}}, %cj.read.inheap.first.start
; CHECK: icmp ult i64 {{%.*}}, %cj.read.inheap.first.end
; CHECK: br i1 %cj.read.inheap.first.hit, label %loadFast, label %cj.read.inheap.scan, !prof
; CHECK: cj.read.inheap.scan:
; CHECK: %cj.read.inheap.n = load i64, i64* @g_cjHeapRangeCount
; CHECK: %cj.read.inheap.count.valid = icmp ule i64 %cj.read.inheap.n, 100
; CHECK: br i1 %cj.read.inheap.count.valid, label %cj.read.inheap.check, label %cj.read.inheap.invalid
; CHECK: cj.read.inheap.check:
; CHECK: [[MORE:%.*]] = icmp ugt i64 %cj.read.inheap.n, 1
; CHECK: br i1 [[MORE]], label %cj.read.inheap.loop, label %loadAccessor
; CHECK: cj.read.inheap.loop:
; CHECK: %cj.read.inheap.index = phi i64 [ 1, %cj.read.inheap.check ], [ %cj.read.inheap.next.index, %cj.read.inheap.next ]
; CHECK: getelementptr inbounds [100 x i64], [100 x i64]* @g_cjHeapRangeStart, i64 0, i64 %cj.read.inheap.index
; CHECK: getelementptr inbounds [100 x i64], [100 x i64]* @g_cjHeapRangeEnd, i64 0, i64 %cj.read.inheap.index
; CHECK: icmp uge i64 {{%.*}}, %cj.read.inheap.start
; CHECK: icmp ult i64 {{%.*}}, %cj.read.inheap.end
; CHECK: br i1 %cj.read.inheap.hit, label %loadFast, label %cj.read.inheap.next
; CHECK: cj.read.inheap.next:
; CHECK: [[LIVE:%.*]] = icmp ult i64 %cj.read.inheap.next.index, %cj.read.inheap.n
; CHECK: br i1 [[LIVE]], label %cj.read.inheap.loop, label %loadAccessor
; CHECK: cj.read.inheap.invalid:
; CHECK: call void @llvm.trap()
; CHECK: unreachable
; CHECK-NOT: cj.read.inheap.result
; CHECK-NOT: cj.read.inheap.done
; CHECK: loadFast:
; CHECK: and i64 {{.*}}, %cj.loadbadmask
; CHECK: br i1 {{.*}}, label %gcNoMarked, label %gcMarked

define i8 addrspace(1)* @p04_read(i8 addrspace(1)* %base,
                                 i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
  %value = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %base,
                       i8 addrspace(1)* addrspace(1)* %slot)
  ret i8 addrspace(1)* %value
}

declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)
declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
