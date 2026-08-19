; RUN: llc --cangjie-pipeline -mtriple=x86_64 -print-after=cj-barrier-lowering \
; RUN:   -print-module-scope -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -cj-generational-post-barrier=false \
; RUN:   -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 \
; RUN:   | FileCheck %s --check-prefix=PHASE

; Z-2 / llstore: heap ref store fast path tests the *slot* (prev) against
; g_cjStoreBadMask (zBarrier.inline.hpp:695-706, Collector.h:265). New SSA
; values are uncoloured, so a value-side test would restore the Idle bare store.
; Slow path stays llvm.cj.gcwrite.ref → MCC (remember + colour).
;
; CHECK: @g_cjStoreBadMask = external global i64
; CHECK-LABEL: define void @write_ref(
; CHECK: [[PLACE:%.*]] = call i8 addrspace(1)* addrspace(1)* @llvm.ptrmask.p1p1i8.i64(i8 addrspace(1)* addrspace(1)* %field, i64 281474976710655)
; CHECK: [[PREV:%.*]] = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* [[PLACE]]
; CHECK: [[PREV_I:%.*]] = ptrtoint i8 addrspace(1)* [[PREV]] to i64
; CHECK: [[MASK:%.*]] = load i64, i64* @g_cjStoreBadMask
; CHECK: [[BAD:%.*]] = and i64 [[PREV_I]], [[MASK]]
; CHECK: [[COLOUR_OK:%.*]] = icmp eq i64 [[BAD]], 0
; CHECK: [[META:%.*]] = and i64 [[PREV_I]], -281474976710656
; CHECK: [[HAS_COLOUR:%.*]] = icmp ne i64 [[META]], 0
; CHECK: [[NEW_I:%.*]] = ptrtoint i8 addrspace(1)* %val to i64
; CHECK: [[PREV_ADDR:%.*]] = and i64 [[PREV_I]], 281474976710655
; CHECK: [[NEW_ADDR:%.*]] = and i64 [[NEW_I]], 281474976710655
; CHECK: [[SAME:%.*]] = icmp eq i64 [[PREV_ADDR]], [[NEW_ADDR]]
; CHECK: [[GOOD:%.*]] = and i1 [[COLOUR_OK]], [[HAS_COLOUR]]
; CHECK: [[FAST:%.*]] = and i1 [[GOOD]], [[SAME]]
; CHECK: [[SLOW:%.*]] = xor i1 [[FAST]], true
; CHECK: br i1 [[SLOW]], label %gcStoreBad, label %storeFinish
; CHECK: gcStoreBad:
; CHECK: call void @CJ_MCC_WriteRefField
; CHECK: storeFinish:
; CHECK: ret void
;
; Compile-time-provable null-base (stack/AS0 contract) stays a plain store.
; CHECK-LABEL: define void @write_ref_null_base(
; CHECK-NOT: g_cjStoreBadMask
; CHECK: store i8 addrspace(1)* %val
; CHECK-NOT: CJ_MCC_WriteRefField
;
; Bulk/atomic stay on the MCC path (A14-A16).
; CHECK-LABEL: define void @atomic_store_ref(
; CHECK: call void @CJ_MCC_AtomicWriteReference
; CHECK-NOT: gcStoreGood
;
; Flag off: historical phase<=INIT Idle arm (gcNoRunning), not the colour test.
; PHASE-LABEL: define void @write_ref(
; PHASE: gcNoRunning:
; PHASE-NOT: g_cjStoreBadMask
; PHASE: gcRunning:

define void @write_ref(i8 addrspace(1)* %val, i8 addrspace(1)* %base,
                       i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
entry:
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %val, i8 addrspace(1)* %base,
                                 i8 addrspace(1)* addrspace(1)* %field)
  ret void
}

define void @write_ref_null_base(i8 addrspace(1)* %val,
                                 i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
entry:
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %val,
                                 i8 addrspace(1)* null,
                                 i8 addrspace(1)* addrspace(1)* %field)
  ret void
}

define void @atomic_store_ref(i8 addrspace(1)* %ref, i8 addrspace(1)* %obj,
                              i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
entry:
  call void @llvm.cj.atomic.store(i8 addrspace(1)* %ref, i8 addrspace(1)* %obj,
                                  i8 addrspace(1)* addrspace(1)* %field, i32 5)
  ret void
}

; Load-then-store: store NewVal is a gcread result. Read lowering must run
; first so ptrtoint sees the load phi, not a still-live gcread call
; (std.core Error.init Verifier crash).
; CHECK-LABEL: define void @write_loaded_ref(
; CHECK: gcNoMarked:
; CHECK: gcStoreBad:
; CHECK: call void @CJ_MCC_WriteRefField
define void @write_loaded_ref(i8 addrspace(1)* %srcobj,
                              i8 addrspace(1)* addrspace(1)* %srcfield,
                              i8 addrspace(1)* %dstobj,
                              i8 addrspace(1)* addrspace(1)* %dstfield) gc "cangjie" {
entry:
  %val = call i8 addrspace(1)* @llvm.cj.gcread.ref(
      i8 addrspace(1)* %srcobj, i8 addrspace(1)* addrspace(1)* %srcfield)
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %val, i8 addrspace(1)* %dstobj,
                                 i8 addrspace(1)* addrspace(1)* %dstfield)
  ret void
}

declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*,
                                  i8 addrspace(1)* addrspace(1)*)
declare i8 addrspace(1)* @llvm.cj.gcread.ref(
    i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
declare void @llvm.cj.atomic.store(i8 addrspace(1)*, i8 addrspace(1)*,
                                   i8 addrspace(1)* addrspace(1)*, i32)
