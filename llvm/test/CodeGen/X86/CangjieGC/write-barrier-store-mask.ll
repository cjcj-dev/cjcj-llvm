; RUN: llc --cangjie-pipeline -mtriple=x86_64 -print-after=cj-barrier-lowering \
; RUN:   -o /dev/null < %s 2>&1 | FileCheck %s

; ZGC x86:457-469 and zAddress.inline.hpp:806: null is store-good colored.
; CHECK-LABEL: define void @write_ref(
; CHECK: storeFast:
; CHECK: load i16
; CHECK: load i64, i64* @g_cjStoreBadMaskOffset
; CHECK: %cj.store.bad = and i64
; CHECK: br i1 {{.*}}, label %storeFinish, label %storeMedium
; CHECK: storeSlow:
; CHECK: call void @CJ_MCC_StoreBarrierOnHeapField
; CHECK: storeFinish:
; CHECK: [[BITS:%.*]] = call i64 asm "movq $1, $0", "=&r,r"(i8 addrspace(1)* %val)
; CHECK: [[SHIFT:%.*]] = load i64, i64* @g_cjLoadShift
; CHECK: load i64, i64* @g_cjStoreGoodMaskOffset
; CHECK: [[NEW:%.*]] = shl i64 [[BITS]], [[SHIFT]]
; CHECK: [[WORD:%.*]] = or i64 [[NEW]], %cj.storegoodmask
; CHECK: store volatile i64 [[WORD]]
; CHECK-NOT: CJ_MCC_PostWriteRefField
; CHECK-LABEL: define void @write_ref_null_val(
; CHECK: storeFinish:
; CHECK: call i64 asm "movq $1, $0", "=&r,r"(i8 addrspace(1)* null)
; CHECK: load i64, i64* @g_cjStoreGoodMaskOffset
; CHECK: or i64 {{.*}}, %cj.storegoodmask
; CHECK-NOT: select i1
; CHECK: store volatile i64
;
; A null base cannot prove that an addrspace(1) destination is non-heap. Route
; it through the MCC producer instead of the old raw-store special case.
; Static/root writes use the distinct gcwrite.static.ref contract.
; CHECK-LABEL: define void @write_ref_null_base(
; CHECK: call void @CJ_MCC_WriteRefField
; CHECK-NOT: store i8 addrspace(1)* %val
; CHECK: ret void
;
; A null base plus a destination derived from an AS0 alloca is a structural
; non-heap proof. Preserve the frozen stack contract and lower it to a raw
; root store (the mutator/root representation remains plain).
; CHECK-LABEL: define void @write_ref_null_base_alloca(
; CHECK-NOT: call void @CJ_MCC_WriteRefField
; CHECK: store i8 addrspace(1)* %val
; CHECK: ret void
; STACK-LABEL: define void @write_ref_null_base_alloca(
; STACK-NOT: call void @CJ_MCC_WriteRefField
; STACK: store i8 addrspace(1)* %val
; STACK-NOT: call void @CJ_MCC_WriteRefField
; STACK: ret void
;
; Bulk/atomic stay on the MCC path (A14-A16).
; CHECK-LABEL: define void @atomic_store_ref(
; CHECK: call void @CJ_MCC_AtomicWriteReference
; CHECK-NOT: gcStoreGood
;

define void @write_ref(i8 addrspace(1)* %val, i8 addrspace(1)* %base,
                       i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
entry:
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %val, i8 addrspace(1)* %base,
                                 i8 addrspace(1)* addrspace(1)* %field, i32 1)
  ret void
}

define void @write_ref_null_val(i8 addrspace(1)* %base,
                                i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
entry:
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* null, i8 addrspace(1)* %base,
                                 i8 addrspace(1)* addrspace(1)* %field, i32 1)
  ret void
}

define void @write_ref_null_base(i8 addrspace(1)* %val,
                                 i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
entry:
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %val,
                                 i8 addrspace(1)* null,
                                 i8 addrspace(1)* addrspace(1)* %field)
  ret void
}

define void @write_ref_null_base_alloca(i8 addrspace(1)* %val) gc "cangjie" {
entry:
  %slot = alloca i8 addrspace(1)*, align 8
  %slot.as1 = addrspacecast i8 addrspace(1)** %slot to i8 addrspace(1)* addrspace(1)*
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %val,
                                 i8 addrspace(1)* null,
                                 i8 addrspace(1)* addrspace(1)* %slot.as1)
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
; CHECK: storeSlow:
; CHECK: call void @CJ_MCC_StoreBarrierOnHeapField
define void @write_loaded_ref(i8 addrspace(1)* %srcobj,
                              i8 addrspace(1)* addrspace(1)* %srcfield,
                              i8 addrspace(1)* %dstobj,
                              i8 addrspace(1)* addrspace(1)* %dstfield) gc "cangjie" {
entry:
  %val = call i8 addrspace(1)* @llvm.cj.gcread.ref(
      i8 addrspace(1)* %srcobj, i8 addrspace(1)* addrspace(1)* %srcfield)
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %val, i8 addrspace(1)* %dstobj,
                                 i8 addrspace(1)* addrspace(1)* %dstfield, i32 1)
  ret void
}

declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)
declare i8 addrspace(1)* @llvm.cj.gcread.ref(
    i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
declare void @llvm.cj.atomic.store(i8 addrspace(1)*, i8 addrspace(1)*,
                                   i8 addrspace(1)* addrspace(1)*, i32)
