; RUN: llc --cangjie-pipeline -mtriple=x86_64 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s --check-prefix=IR --implicit-check-not=g_cjThreadGCDataOffset --implicit-check-not=g_cjLoadBadMaskOffset --implicit-check-not=g_cjStoreBadMaskOffset --implicit-check-not=g_cjStoreGoodMaskOffset --implicit-check-not=g_cjStoreBarrierBufferOffset
; RUN: llc --cangjie-pipeline -mtriple=aarch64 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s --check-prefix=IR --implicit-check-not=g_cjThreadGCDataOffset --implicit-check-not=g_cjLoadBadMaskOffset --implicit-check-not=g_cjStoreBadMaskOffset --implicit-check-not=g_cjStoreGoodMaskOffset --implicit-check-not=g_cjStoreBarrierBufferOffset
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -o - < %s | FileCheck %s --check-prefix=X86 --implicit-check-not=g_cjThreadGCDataOffset --implicit-check-not=g_cjLoadBadMaskOffset --implicit-check-not=g_cjStoreBadMaskOffset --implicit-check-not=g_cjStoreGoodMaskOffset --implicit-check-not=g_cjStoreBarrierBufferOffset
; RUN: llc --cangjie-pipeline -mtriple=aarch64 -o - < %s | FileCheck %s --check-prefix=A64 --implicit-check-not=g_cjThreadGCDataOffset --implicit-check-not=g_cjLoadBadMaskOffset --implicit-check-not=g_cjStoreBadMaskOffset --implicit-check-not=g_cjStoreGoodMaskOffset --implicit-check-not=g_cjStoreBarrierBufferOffset
; ABI source: runtime/src/Heap/z/zThreadLocalDataABI.hpp at
; f51bbe7e8e75830dcc0c5f69d1f48ec01e5d86c4 (#944). Runtime static_asserts
; bind this table to real layouts. ZGC zThreadLocalData.hpp:115-133 and
; zBarrierSetAssembler_x86.cpp:455-478 use constant offsets. Cangjie's M:N
; carrier needs one extra pointer load at 96; adding 96 to a mask offset is
; incorrect. Buffer-internal offsets remain runtime-provided.

; IR-LABEL: define i8 addrspace(1)* @read_fixed(
; IR: %cj.gcdata = call i8* asm sideeffect {{.*}}(i64 96)
; IR: [[MASKADDR:%.*]] = getelementptr i8, i8* %cj.gcdata, i64 8
; IR: [[MASKPTR:%.*]] = bitcast i8* [[MASKADDR]] to i64*
; IR: %cj.loadbadmask = load i64, i64* [[MASKPTR]]
; IR: and i64 {{.*}}, %cj.loadbadmask
; X86-LABEL: read_fixed:
; X86: movq 96(%r15)
; X86: testq {{.*}}8(
; A64-LABEL: read_fixed:
; A64: ldr {{x[0-9]+}}, [x28, #96]
; A64: ldr {{x[0-9]+}}, [{{x[0-9]+}}, #8]
define i8 addrspace(1)* @read_fixed(i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
  %r = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot)
  ret i8 addrspace(1)* %r
}

; IR-LABEL: define void @store_fixed(
; IR: storeFast:
; IR: %cj.gcdata = call i8* asm sideeffect {{.*}}(i64 96)
; IR: [[BADADDR:%.*]] = getelementptr i8, i8* %cj.gcdata, i64 32
; IR: [[BADPTR:%.*]] = bitcast i8* [[BADADDR]] to i64*
; IR: %cj.storebadmask = load i64, i64* [[BADPTR]]
; IR: %cj.store.bad = and i64 %cj.store.prev.low, %cj.storebadmask
; IR: storeMedium:
; IR: [[BUFADDR:%.*]] = getelementptr i8, i8* %cj.gcdata, i64 40
; IR: [[BUFPTR:%.*]] = bitcast i8* [[BUFADDR]] to i8**
; IR: %cj.store.buffer = load i8*, i8** [[BUFPTR]]
; IR: load i64, i64* @g_cjStoreBarrierBufferCurrentOffset
; IR: storeFinish:
; IR: [[GC:%.*]] = call i8* asm sideeffect {{.*}}(i64 96)
; IR: [[GOODADDR:%.*]] = getelementptr i8, i8* [[GC]], i64 24
; IR: [[GOODPTR:%.*]] = bitcast i8* [[GOODADDR]] to i64*
; IR: %cj.storegoodmask = load i64, i64* [[GOODPTR]]
; IR: %cj.store.colored = or i64 {{.*}}, %cj.storegoodmask
; X86-LABEL: store_fixed:
; X86: movq 96(%r15)
; X86: test{{[lq]}} {{.*}}32(
; X86: movq 40(
; X86: orq 24(
; A64-LABEL: store_fixed:
; A64: ldr {{x[0-9]+}}, [x28, #96]
; A64: ldr {{x[0-9]+}}, [{{x[0-9]+}}, #32]
; A64: ldr {{x[0-9]+}}, [{{x[0-9]+}}, #40]
; A64: ldr {{x[0-9]+}}, [{{x[0-9]+}}, #24]
define void @store_fixed(i8 addrspace(1)* %value, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot, i32 1)
  ret void
}

; zStorePNull (z_x86_64.ad:180-185) must store the current good mask itself.
; IR-LABEL: define void @elided_null_fixed(
; IR: %cj.gcdata = call i8* asm sideeffect {{.*}}(i64 96)
; IR-NEXT: [[NULLADDR:%.*]] = getelementptr i8, i8* %cj.gcdata, i64 24
; IR-NEXT: [[NULLPTR:%.*]] = bitcast i8* [[NULLADDR]] to i64*
; IR-NEXT: %cj.storegoodmask = load i64, i64* [[NULLPTR]]
; IR: store volatile i64 %cj.storegoodmask
; IR-NEXT: ret void
; X86-LABEL: elided_null_fixed:
; X86: movq 96(%r15), [[GC:%r[a-z0-9]+]]
; X86: movq 24([[GC]]), [[GOOD:%r[a-z0-9]+]]
; X86: movq [[GOOD]], (
; X86: retq
; A64-LABEL: elided_null_fixed:
; A64: ldr [[GC:x[0-9]+]], [x28, #96]
; A64: ldr [[GOOD:x[0-9]+]], {{\[}}[[GC]], #24]
; A64: str [[GOOD]], [
; A64: ret
define void @elided_null_fixed(i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* null, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot, i32 1), !cj.barrier.elided !0
  ret void
}
!0 = !{}

declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)
