; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s --check-prefixes=FIXED,COMMON --implicit-check-not=g_cjStoreBarrier
; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu -o - < %s | FileCheck %s --check-prefix=ASM --implicit-check-not=g_cjStoreBarrier
; RUN: llc --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu -stop-after=cj-barrier-lowering -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s --check-prefixes=DYNAMIC,COMMON
; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-musl -stop-after=cj-barrier-lowering -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s --check-prefixes=DYNAMIC,COMMON
; RUN: llc --cangjie-pipeline -mtriple=x86_64-pc-windows-msvc -stop-after=cj-barrier-lowering -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s --check-prefixes=DYNAMIC,COMMON
; RUN: llc --cangjie-pipeline -mtriple=x86_64-apple-darwin -stop-after=cj-barrier-lowering -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s --check-prefixes=DYNAMIC,COMMON
; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnux32 -stop-after=cj-barrier-lowering -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s --check-prefixes=DYNAMIC,COMMON
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -stop-after=cj-barrier-lowering -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s --check-prefixes=DYNAMIC,COMMON
; current follows std::mutex: only the explicitly checked Linux GNU LP64
; runtime ABI may use 824. Unknown and different libc/OS/arch ABIs use exports.
; No change to the dynamic current value, slow branch, entry write ordering,
; coloring, or independent read/weak-store barriers.

; COMMON-LABEL: define void @strong(
; COMMON: storeMedium:
; COMMON: %cj.store.buffer = load i8*, i8**
; FIXED: [[CURBYTE:%.*]] = getelementptr i8, i8* %cj.store.buffer, i64 824
; DYNAMIC: load i64, i64* @g_cjStoreBarrierBufferCurrentOffset
; COMMON: [[CURPTR:%.*]] = bitcast i8* {{.*}} to i64*
; COMMON-NEXT: %cj.store.current = load i64, i64* [[CURPTR]]
; COMMON-NEXT: [[EMPTY:%.*]] = icmp eq i64 %cj.store.current, 0
; COMMON-NEXT: br i1 [[EMPTY]], label %storeSlow, label %storeAppend
; COMMON: storeAppend:
; DYNAMIC: load i64, i64* @g_cjStoreBarrierEntrySize
; FIXED-NEXT: %cj.store.next = sub i64 %cj.store.current, 16
; DYNAMIC: %cj.store.next = sub i64 %cj.store.current,
; COMMON-NEXT: store i64 %cj.store.next, i64* [[CURPTR]]
; FIXED-NEXT: [[ENTRIES:%.*]] = getelementptr i8, i8* %cj.store.buffer, i64 0
; DYNAMIC: load i64, i64* @g_cjStoreBarrierBufferBufferOffset
; COMMON: %cj.store.entry = getelementptr i8, i8* {{.*}}, i64 %cj.store.next
; FIXED-NEXT: [[PBYTE:%.*]] = getelementptr i8, i8* %cj.store.entry, i64 0
; DYNAMIC: load i64, i64* @g_cjStoreBarrierEntryPOffset
; COMMON: [[P:%.*]] = bitcast i8* {{.*}} to i64*
; COMMON: store i64 {{.*}}, i64* [[P]]
; COMMON-NEXT: %cj.store.buffer.prev = load i64, i64* {{.*}}
; FIXED-NEXT: [[PREVBYTE:%.*]] = getelementptr i8, i8* %cj.store.entry, i64 8
; DYNAMIC: load i64, i64* @g_cjStoreBarrierEntryPrevOffset
; COMMON: [[PREV:%.*]] = bitcast i8* {{.*}} to i64*
; COMMON-NEXT: store i64 %cj.store.buffer.prev, i64* [[PREV]]
; COMMON-NEXT: br label %storeFinish
; COMMON: storeSlow:
; COMMON: call void @CJ_MCC_StoreBarrierOnHeapField(
; COMMON-NEXT: br label %storeFinish
; COMMON: storeFinish:
; COMMON: %cj.store.shift = load i64, i64* @g_cjLoadShift
; COMMON: %cj.storegoodmask = load i64,
; COMMON: %cj.store.colored = or i64 {{.*}}, %cj.storegoodmask
; COMMON: store volatile i64 %cj.store.colored
; ASM-LABEL: strong:
; ASM: 824(
; ASM: CJ_MCC_StoreBarrierOnHeapField
; ASM: g_cjLoadShift
define void @strong(i8 addrspace(1)* %value, i8 addrspace(1)* %base,
                    i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot, i32 1)
  ret void
}

; COMMON-LABEL: define void @weak(
; COMMON: storeMedium:
; COMMON-NEXT: br label %storeSlow
; COMMON: call void @CJ_MCC_StoreBarrierOnHeapFieldNoKeepAlive(
define void @weak(i8 addrspace(1)* %value, i8 addrspace(1)* %base,
                  i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot, i32 2)
  ret void
}

; COMMON-LABEL: define i8 addrspace(1)* @read_control(
; COMMON: %cj.loadbadmask = load i64,
; COMMON: call i8 addrspace(1)* @CJ_MCC_LoadBarrierOnOopFieldPreloaded(
define i8 addrspace(1)* @read_control(i8 addrspace(1)* %base,
                                     i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
  %r = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot)
  ret i8 addrspace(1)* %r
}

declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)
declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
