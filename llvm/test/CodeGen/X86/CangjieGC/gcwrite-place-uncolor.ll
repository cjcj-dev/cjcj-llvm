; RUN: llc --cangjie-pipeline -mtriple=x86_64 -print-after=cj-barrier-lowering \
; RUN:   -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -cj-store-good-paint=0 \
; RUN:   -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 \
; RUN:   | FileCheck %s --check-prefix=NOPAINT

; Default: peel colour from the place before loading prev, then OR
; g_cjStoreGoodMask on the hit arm.
; =0: same peel; census hit is a no-op rewrite. No paint.

define void @write_ref_place(i8 addrspace(1)* %val, i8 addrspace(1)* %base,
                             i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
; CHECK-LABEL: define void @write_ref_place(
; CHECK: [[PLACE_PLAIN:%.*]] = call i8 addrspace(1)* addrspace(1)* @llvm.ptrmask.p1p1i8.i64(i8 addrspace(1)* addrspace(1)* %field, i64 281474976710655)
; CHECK: load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* [[PLACE_PLAIN]]
; CHECK: load i64, i64* @g_cjStoreBadMask
; CHECK: storeFinish:
; CHECK: load i64, i64* @g_cjStoreGoodMask
; CHECK: gcStoreBad:
; CHECK: call void @CJ_MCC_WriteRefField
; NOPAINT-LABEL: define void @write_ref_place(
; NOPAINT: [[NPLACE:%.*]] = call i8 addrspace(1)* addrspace(1)* @llvm.ptrmask.p1p1i8.i64(i8 addrspace(1)* addrspace(1)* %field, i64 281474976710655)
; NOPAINT: load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* [[NPLACE]]
; NOPAINT: load i64, i64* @g_cjStoreBadMask
; NOPAINT-NOT: g_cjStoreGoodMask
; NOPAINT: gcStoreBad:
; NOPAINT: call void @CJ_MCC_WriteRefField
entry:
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %val, i8 addrspace(1)* %base,
                                 i8 addrspace(1)* addrspace(1)* %field)
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

declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*,
                                  i8 addrspace(1)* addrspace(1)*)
declare void @llvm.cj.atomic.store(i8 addrspace(1)*, i8 addrspace(1)*,
                                   i8 addrspace(1)* addrspace(1)*, i32)
