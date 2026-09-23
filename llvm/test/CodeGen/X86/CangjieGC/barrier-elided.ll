; RUN: opt -passes=cj-ir-verifier -disable-output < %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O0 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; ZGC zBarrierSetC2.hpp:37, z_x86_64.ad:61-99,180-185.
; B0 consumes an existing proof, without introducing a producer.

define void @elided_store(i8 addrspace(1)* %value, i8 addrspace(1)* %base,
                          i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
; CHECK-LABEL: define void @elided_store(
; CHECK-NOT: g_cjStoreBadMaskOffset
; CHECK-NOT: CJ_MCC_
; CHECK: %cj.store.new.bits = call i64 asm
; CHECK: load i64, i64* @g_cjLoadShift
; CHECK: load i64, i64* @g_cjStoreGoodMaskOffset
; CHECK: shl i64 %cj.store.new.bits, %cj.store.shift
; CHECK: %cj.store.colored = or i64 {{.*}}, %cj.storegoodmask
; CHECK: store volatile i64 %cj.store.colored
; CHECK-NEXT: ret void
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot, i32 1), !cj.barrier.elided !0
  ret void
}

define void @elided_unknown_store(i8 addrspace(1)* %value, i8 addrspace(1)* %base,
                          i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
; CHECK-LABEL: define void @elided_unknown_store(
; CHECK-NOT: g_cjStoreBadMaskOffset
; CHECK-NOT: CJ_MCC_
; CHECK: %cj.store.new.bits = call i64 asm
; CHECK: load i64, i64* @g_cjLoadShift
; CHECK: load i64, i64* @g_cjStoreGoodMaskOffset
; CHECK: shl i64 %cj.store.new.bits, %cj.store.shift
; CHECK: %cj.store.colored = or i64 {{.*}}, %cj.storegoodmask
; CHECK: store volatile i64 %cj.store.colored
; CHECK-NEXT: ret void
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot, i32 0), !cj.barrier.elided !0
  ret void
}

define void @ordinary_store(i8 addrspace(1)* %value, i8 addrspace(1)* %base,
                          i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
; CHECK-LABEL: define void @ordinary_store(
; CHECK: load i64, i64* @g_cjStoreBadMaskOffset
; CHECK: load i64, i64* @g_cjStoreBarrierBufferCurrentOffset
; CHECK: call void @CJ_MCC_StoreBarrierOnHeapField(
; CHECK: load i64, i64* @g_cjStoreGoodMaskOffset
; CHECK: store volatile i64 %cj.store.colored
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot, i32 1)
  ret void
}

define void @elided_null(i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
; CHECK-LABEL: define void @elided_null(
; CHECK-NOT: g_cjStoreBadMaskOffset
; CHECK-NOT: cj.store.new.bits
; CHECK-NOT: g_cjLoadShift
; CHECK: load i64, i64* @g_cjStoreGoodMaskOffset
; CHECK: store volatile i64 %cj.storegoodmask
; CHECK-NEXT: ret void
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* null, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot, i32 1), !cj.barrier.elided !0
  ret void
}

define i8 addrspace(1)* @elided_load(i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
; CHECK-LABEL: define i8 addrspace(1)* @elided_load(
; CHECK-NEXT: [[LOAD:%.*]] = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %slot, {{.*}}!cj.colored.value
; CHECK-NEXT: [[BITS:%.*]] = ptrtoint i8 addrspace(1)* [[LOAD]] to i64
; CHECK-NEXT: %cj.load.shift = load i64, i64* @g_cjLoadShift
; CHECK-NEXT: %cj.load.address = lshr i64 [[BITS]], %cj.load.shift
; CHECK-NEXT: [[VALUE:%.*]] = inttoptr i64 %cj.load.address to i8 addrspace(1)*
; CHECK-NEXT: ret i8 addrspace(1)* [[VALUE]]
  %value = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot), !cj.barrier.elided !0
  ret i8 addrspace(1)* %value
}

define i8 addrspace(1)* @ordinary_load(i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
; CHECK-LABEL: define i8 addrspace(1)* @ordinary_load(
; CHECK: load i64, i64* @g_cjLoadBadMaskOffset
; CHECK: call i8 addrspace(1)* @CJ_MCC_ReadRefField(
; CHECK: lshr i64
  %value = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot)
  ret i8 addrspace(1)* %value
}

define i8 addrspace(1)* @elided_static_load(i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
; CHECK-LABEL: define i8 addrspace(1)* @elided_static_load(
; CHECK-NEXT: [[LOAD:%.*]] = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %slot{{.*}}!cj.colored.value
; CHECK-NEXT: [[BITS:%.*]] = ptrtoint i8 addrspace(1)* [[LOAD]] to i64
; CHECK-NEXT: %cj.load.shift = load i64, i64* @g_cjLoadShift
; CHECK-NEXT: %cj.load.address = lshr i64 [[BITS]], %cj.load.shift
; CHECK-NEXT: [[VALUE:%.*]] = inttoptr i64 %cj.load.address to i8 addrspace(1)*
; CHECK-NEXT: ret i8 addrspace(1)* [[VALUE]]
  %value = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)* addrspace(1)* %slot), !cj.barrier.elided !0
  ret i8 addrspace(1)* %value
}

define i8 addrspace(1)* @elided_atomic_load(i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
; CHECK-LABEL: define i8 addrspace(1)* @elided_atomic_load(
; CHECK-NEXT: [[LOAD:%.*]] = load atomic i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %slot{{.*}}!cj.colored.value
; CHECK-NEXT: [[BITS:%.*]] = ptrtoint i8 addrspace(1)* [[LOAD]] to i64
; CHECK-NEXT: %cj.load.shift = load i64, i64* @g_cjLoadShift
; CHECK-NEXT: %cj.load.address = lshr i64 [[BITS]], %cj.load.shift
; CHECK-NEXT: [[VALUE:%.*]] = inttoptr i64 %cj.load.address to i8 addrspace(1)*
; CHECK-NEXT: ret i8 addrspace(1)* [[VALUE]]
  %value = call i8 addrspace(1)* @llvm.cj.atomic.load(i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot, i32 5), !cj.barrier.elided !0
  ret i8 addrspace(1)* %value
}

declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)
declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
!0 = !{}

declare i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)* addrspace(1)*)
declare i8 addrspace(1)* @llvm.cj.atomic.load(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, i32)
