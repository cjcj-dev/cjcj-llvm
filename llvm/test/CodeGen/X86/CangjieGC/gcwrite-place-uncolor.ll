; RUN: llc --cangjie-pipeline -mtriple=x86_64 -print-after=cj-barrier-lowering \
; RUN:   -o /dev/null < %s 2>&1 | FileCheck %s

; ZGC x86:457-469: the slot is an uncolored address; the stored word is colored.

define void @write_ref_place(i8 addrspace(1)* %val, i8 addrspace(1)* %base,
                             i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
; CHECK-LABEL: define void @write_ref_place(
; CHECK: storeFast:
; CHECK: bitcast i8 addrspace(1)* addrspace(1)* %field to i16 addrspace(1)*
; CHECK: load i16
; CHECK: load i64, i64* @g_cjStoreBadMaskOffset
; CHECK: storeSlow:
; CHECK: call void @CJ_MCC_StoreBarrierOnHeapField
; CHECK: storeFinish:
; CHECK: load i64, i64* @g_cjStoreGoodMaskOffset
entry:
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %val, i8 addrspace(1)* %base,
                                 i8 addrspace(1)* addrspace(1)* %field, i32 1)
  ret void
}

define void @atomic_store_place(i8 addrspace(1)* %ref, i8 addrspace(1)* %obj,
                                i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
; CHECK-LABEL: define void @atomic_store_place(
; CHECK: call void @CJ_MCC_AtomicWriteReference
entry:
  call void @llvm.cj.atomic.store(i8 addrspace(1)* %ref, i8 addrspace(1)* %obj,
                                  i8 addrspace(1)* addrspace(1)* %field, i32 5)
  ret void
}

declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)
declare void @llvm.cj.atomic.store(i8 addrspace(1)*, i8 addrspace(1)*,
                                   i8 addrspace(1)* addrspace(1)*, i32)
