; RUN: opt --cangjie-pipeline -S -passes='default<O2>' %s -o %t
; RUN: FileCheck %s --check-prefix=IR < %t
; RUN: llc --cangjie-pipeline -mtriple=x86_64 %t -o - | FileCheck %s --check-prefix=ASM
; ZGC memnode.hpp:48 and zBarrierSetC2.cpp:342-373: the store decorator
; is semantic node state, preserved across the actual optimizing pipeline.
; Equal-strength stores may fold; different strengths remain distinct.

declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)
define void @strong(i1 %c, i8 addrspace(1)* %v, i8 addrspace(1)* %w, i8 addrspace(1)* %base, i8 addrspace(1)* %slot.raw) gc "cangjie" {
; IR-LABEL: define void @strong(
; IR-NOT: br i1
; IR: @llvm.cj.gcwrite.ref({{.*}}i32 1)
; IR-NOT: @llvm.cj.gcwrite.ref(
; IR: ret void
; ASM-LABEL: strong:
; ASM-DAG: g_cjThreadGCDataOffset
; ASM-DAG: g_cjStoreBadMaskOffset
; ASM-DAG: g_cjStoreBarrierBufferOffset
; ASM-DAG: g_cjStoreBarrierBufferCurrentOffset
; ASM-DAG: g_cjStoreBarrierEntryPOffset
; ASM-DAG: g_cjStoreBarrierEntryPrevOffset
; ASM-DAG: CJ_MCC_WriteRefField_Strong
; ASM-DAG: CJ_MCC_StoreBarrierOnHeapField@PLT
entry:
 %slot = bitcast i8 addrspace(1)* %slot.raw to i8 addrspace(1)* addrspace(1)*
 br i1 %c, label %a, label %b
a:
 call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %v, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot, i32 1)
 br label %end
b:
 call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %v, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot, i32 1)
 br label %end
end:
 ret void
}
define void @weak(i1 %c, i8 addrspace(1)* %v, i8 addrspace(1)* %w, i8 addrspace(1)* %base, i8 addrspace(1)* %slot.raw) gc "cangjie" {
; IR-LABEL: define void @weak(
; IR-NOT: br i1
; IR: @llvm.cj.gcwrite.ref({{.*}}i32 2)
; IR-NOT: @llvm.cj.gcwrite.ref(
; IR: ret void
; ASM-LABEL: weak:
; ASM-DAG: g_cjThreadGCDataOffset
; ASM-DAG: g_cjStoreBadMaskOffset
; ASM-DAG: CJ_MCC_WriteRefField_Weak
; ASM-DAG: CJ_MCC_StoreBarrierOnHeapFieldNoKeepAlive
entry:
 %slot = bitcast i8 addrspace(1)* %slot.raw to i8 addrspace(1)* addrspace(1)*
 br i1 %c, label %a, label %b
a:
 call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %v, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot, i32 2)
 br label %end
b:
 call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %v, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot, i32 2)
 br label %end
end:
 ret void
}
define void @mixed(i1 %c, i8 addrspace(1)* %v, i8 addrspace(1)* %w, i8 addrspace(1)* %base, i8 addrspace(1)* %slot.raw) gc "cangjie" {
; IR-LABEL: define void @mixed(
; IR: br i1
; IR-DAG: @llvm.cj.gcwrite.ref({{.*}}i32 1)
; IR-DAG: @llvm.cj.gcwrite.ref({{.*}}i32 2)
; IR: ret void
; ASM-LABEL: mixed:
; ASM-DAG: CJ_MCC_WriteRefField_Strong
; ASM-DAG: CJ_MCC_WriteRefField_Weak
; ASM-DAG: CJ_MCC_StoreBarrierOnHeapField@PLT
; ASM-DAG: CJ_MCC_StoreBarrierOnHeapFieldNoKeepAlive
entry:
 %slot = bitcast i8 addrspace(1)* %slot.raw to i8 addrspace(1)* addrspace(1)*
 br i1 %c, label %a, label %b
a:
 call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %v, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot, i32 1)
 br label %end
b:
 call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %v, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot, i32 2)
 br label %end
end:
 ret void
}
define void @unknown(i1 %c, i8 addrspace(1)* %v, i8 addrspace(1)* %w, i8 addrspace(1)* %base, i8 addrspace(1)* %slot.raw) gc "cangjie" {
; IR-LABEL: define void @unknown(
; IR: @llvm.cj.gcwrite.ref({{.*}}%slot)
; IR-NOT: i32 1)
; IR-NOT: i32 2)
; IR: ret void
; ASM-LABEL: unknown:
; ASM: {{[[:space:]]}}CJ_MCC_WriteRefField{{(@PLT)?$}}
; ASM-NOT: CJ_MCC_WriteRefField_
; ASM-NOT: CJ_MCC_StoreBarrier
entry:
 %slot = bitcast i8 addrspace(1)* %slot.raw to i8 addrspace(1)* addrspace(1)*
 br i1 %c, label %a, label %b
a:
 call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %v, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot)
 br label %end
b:
 call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %v, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot)
 br label %end
end:
 ret void
}
