; RUN: llc --cangjie-pipeline -mtriple=x86_64 -o - < %s | FileCheck %s --check-prefix=ASM
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; ZGC zBarrierSetAssembler_x86.cpp:457-504,615-628: non-nmethod heap store.
; The slot-domain branch precedes the heap fast/medium/slow decomposition.

define void @strong(i8 addrspace(1)* %value, i8 addrspace(1)* %base,
                    i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
; CHECK-LABEL: define void @strong(
; CHECK: storeFast:
; CHECK: call i8* asm sideeffect "movq %r15, $0"
; CHECK: load i64, i64* @g_cjThreadGCDataOffset
; CHECK: load i64, i64* @g_cjStoreBadMaskOffset
; CHECK: %cj.store.bad = and i64
; CHECK: br i1 {{.*}}, label %storeFinish, label %storeMedium
; CHECK: storeMedium:
; CHECK: load i64, i64* @g_cjStoreBarrierBufferCurrentOffset
; CHECK: %cj.store.current = load i64
; CHECK: icmp eq i64 %cj.store.current, 0
; CHECK: br i1 {{.*}}, label %storeSlow, label %storeAppend
; CHECK: storeAppend:
; CHECK: load i64, i64* @g_cjStoreBarrierEntrySize
; CHECK: %cj.store.next = sub i64 %cj.store.current
; CHECK: store i64 %cj.store.next
; CHECK: load i64, i64* @g_cjStoreBarrierEntryPOffset
; CHECK: store i64
; CHECK: load i64, i64* @g_cjStoreBarrierEntryPrevOffset
; CHECK: store i64 %cj.store.buffer.prev
; CHECK: br label %storeFinish
; CHECK: storeSlow:
; CHECK: call void @CJ_MCC_StoreBarrierOnHeapField(
; CHECK-NEXT: br label %storeFinish
; CHECK: storeFinish:
; CHECK: load i64, i64* @g_cjStoreGoodMaskOffset
; CHECK: store volatile i64 %cj.store.colored
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot, i32 1)
  ret void
}

define void @weak(i8 addrspace(1)* %value, i8 addrspace(1)* %base,
                  i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
; CHECK-LABEL: define void @weak(
; CHECK: storeMedium:
; CHECK-NEXT: br label %storeSlow
; CHECK: storeSlow:
; CHECK: call void @CJ_MCC_StoreBarrierOnHeapFieldNoKeepAlive(
; CHECK-NEXT: br label %storeFinish
; CHECK: storeFinish:
; CHECK: store volatile i64 %cj.store.colored
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot, i32 2)
  ret void
}

define void @unknown(i8 addrspace(1)* %value, i8 addrspace(1)* %base,
                     i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
; CHECK-LABEL: define void @unknown(
; CHECK-NOT: storeMedium
; CHECK: call void @CJ_MCC_WriteRefField(
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot, i32 0)
  ret void
}

declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)

; ASM-LABEL: strong:
; ASM: %r15
; ASM: g_cjThreadGCDataOffset
; ASM: g_cjStoreBadMaskOffset
; ASM: g_cjStoreBarrierBufferCurrentOffset
; ASM: g_cjStoreBarrierEntrySize
; ASM: g_cjStoreBarrierEntryPOffset
; ASM: g_cjStoreBarrierEntryPrevOffset
; ASM: CJ_MCC_StoreBarrierOnHeapField
; ASM-LABEL: weak:
; ASM: CJ_MCC_StoreBarrierOnHeapFieldNoKeepAlive
; ASM-LABEL: unknown:
; ASM: CJ_MCC_WriteRefField
