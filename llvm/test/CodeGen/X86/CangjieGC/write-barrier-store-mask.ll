; RUN: llc --cangjie-pipeline -mtriple=x86_64 -print-after=cj-barrier-lowering \
; RUN:   -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -cj-generational-post-barrier=false \
; RUN:   -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 \
; RUN:   | FileCheck %s --check-prefix=PHASE

; Z-2 / llstore3: heap ref store fast path tests the *slot* (prev) against
; g_cjStoreBadMask only (zBarrierSetAssembler_x86.cpp:358-374). Hit arm is
; color_store_good: ptrmask-peel new, OR g_cjStoreGoodMask unless new is
; null (WCollector.h:756-758 GetAndTryTagRefField(nullptr) stays plain).
; Store the word as i64. No has-colour, no same-target.
; Slow path stays llvm.cj.gcwrite.ref → MCC (remember + colour).
;
; CHECK-LABEL: define void @write_ref(
; CHECK: [[PLACE:%.*]] = call i8 addrspace(1)* addrspace(1)* @llvm.ptrmask.p1p1i8.i64(i8 addrspace(1)* addrspace(1)* %field, i64 281474976710655)
; CHECK: [[PREV:%.*]] = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* [[PLACE]]
; CHECK: [[PREV_I:%.*]] = ptrtoint i8 addrspace(1)* [[PREV]] to i64
; CHECK: [[MASK:%.*]] = load i64, i64* @g_cjStoreBadMask
; CHECK: [[BAD:%.*]] = and i64 [[PREV_I]], [[MASK]]
; CHECK: [[COLOUR_OK:%.*]] = icmp eq i64 [[BAD]], 0
; CHECK-NOT: cj.store.hascolour
; CHECK-NOT: cj.store.same
; CHECK: br i1 [[COLOUR_OK]], label %storeFinish, label %gcStoreBad
; CHECK: storeFinish:
; CHECK: [[NEW_PLAIN:%.*]] = call i8 addrspace(1)* @llvm.ptrmask.p1i8.i64(i8 addrspace(1)* %val, i64 281474976710655)
; CHECK: [[NEW_I:%.*]] = ptrtoint i8 addrspace(1)* [[NEW_PLAIN]] to i64
; CHECK: [[GOODMASK:%.*]] = load i64, i64* @g_cjStoreGoodMask
; CHECK: [[COLORED_I:%.*]] = or i64 [[NEW_I]], [[GOODMASK]]
; CHECK: [[ISNULL:%.*]] = icmp eq i64 [[NEW_I]], 0
; CHECK: [[WORD:%.*]] = select i1 [[ISNULL]], i64 [[NEW_I]], i64 [[COLORED_I]]
; CHECK: [[PLACE_I64:%.*]] = bitcast i8 addrspace(1)* addrspace(1)* [[PLACE]] to i64 addrspace(1)*
; CHECK: store volatile i64 [[WORD]], i64 addrspace(1)* [[PLACE_I64]]
; CHECK: gcStoreBad:
; CHECK: call void @CJ_MCC_WriteRefField
;
; Null new value stays plain 0 (WCollector.h:756-758), not StoreGood-coloured.
; CHECK-LABEL: define void @write_ref_null_val(
; CHECK: storeFinish:
; CHECK: cj.store.new.isnull
; CHECK: select i1
; CHECK: store i64
; CHECK: gcStoreBad:
;
; Compile-time-provable null-base (stack/AS0 contract) stays a plain store.
; CHECK-LABEL: define void @write_ref_null_base(
; CHECK-NOT: g_cjStoreBadMask
; CHECK-NOT: g_cjStoreGoodMask
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
; PHASE-NOT: g_cjStoreGoodMask
; PHASE: gcRunning:

define void @write_ref(i8 addrspace(1)* %val, i8 addrspace(1)* %base,
                       i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
entry:
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %val, i8 addrspace(1)* %base,
                                 i8 addrspace(1)* addrspace(1)* %field)
  ret void
}

define void @write_ref_null_val(i8 addrspace(1)* %base,
                                i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
entry:
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* null, i8 addrspace(1)* %base,
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
