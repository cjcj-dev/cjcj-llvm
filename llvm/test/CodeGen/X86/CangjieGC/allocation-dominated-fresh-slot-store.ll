; RUN: opt -passes=cj-ir-verifier -disable-output < %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 -enable-gc-fast-path=false -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=aarch64 -O2 -enable-gc-fast-path=false -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; ZGC zBarrierSetC2.cpp:498-508; barrierSetC2.cpp:973-1003, 1041-1112.
; Fresh-allocation initialization stores: a non-inbounds constant-offset slot
; of the allocation result, and array TypeInfo named through an internal
; alias. Colored stores stay; every unproven slot keeps its full barrier.
target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"

%cti = type { i8*, i8, i8, i16, i32 }
%ati = type { i8*, i8, i8, i16, i32, i8*, i64, i8, i8, i16, i8*, i8*, i8*, i8*, i8* }
@component_ti = constant %cti { i8* null, i8 -128, i8 0, i16 0, i32 64 }
@array_ti = constant %ati { i8* null, i8 -126, i8 0, i16 0, i32 0, i8* null, i64 0, i8 0, i8 0, i16 0, i8* null, i8* null, i8* null, i8* null, i8* bitcast (%cti* @component_ti to i8*) }
@array_ti_alias = internal alias %ati, %ati* @array_ti
@array_ti_weak = weak alias %ati, %ati* @array_ti

; Object field written through a non-inbounds GEP, as the inlined iterator
; constructors do: both in-extent slots are elided, colors are kept.
; CHECK-LABEL: define void @object_noninbounds(
; CHECK-NOT: cj.store.prev.low
; CHECK-NOT: CJ_MCC_StoreBarrierOnHeapField
; CHECK: store volatile i64 %cj.store.colored
; CHECK-NOT: cj.store.prev.low
; CHECK: store volatile i64 %cj.store.colored
; CHECK: ret void
define void @object_noninbounds(i8* %type, i8 addrspace(1)* %value) gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i64)* @CJ_MCC_NewObject, i32 2, i32 0, i8* %type, i64 24)
  %heap = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  %f8 = getelementptr i8, i8 addrspace(1)* %heap, i64 8
  %s8 = bitcast i8 addrspace(1)* %f8 to i8 addrspace(1)* addrspace(1)*
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %heap, i8 addrspace(1)* addrspace(1)* %s8, i32 1)
  %f16 = getelementptr i8, i8 addrspace(1)* %heap, i64 16
  %s16 = bitcast i8 addrspace(1)* %f16 to i8 addrspace(1)* addrspace(1)*
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %heap, i8 addrspace(1)* addrspace(1)* %s16, i32 1)
  ret void
}

; The slot [16, 24) ends past the 16-byte allocation: full barrier.
; CHECK-LABEL: define void @object_past_end(
; CHECK: cj.store.prev.low
; CHECK: call void @CJ_MCC_StoreBarrierOnHeapField
; CHECK: store volatile i64 %cj.store.colored
define void @object_past_end(i8* %type, i8 addrspace(1)* %value) gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i64)* @CJ_MCC_NewObject, i32 2, i32 0, i8* %type, i64 16)
  %heap = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  %f = getelementptr i8, i8 addrspace(1)* %heap, i64 16
  %s = bitcast i8 addrspace(1)* %f to i8 addrspace(1)* addrspace(1)*
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %heap, i8 addrspace(1)* addrspace(1)* %s, i32 1)
  ret void
}

; Offset 0 is the TypeInfo pointer, not an initialized field slot: the
; non-inbounds admission requires the slot to lie past the object header.
; (A plain bitcast of the allocation already took the pre-existing inbounds
; allocation-origin path, which this change does not alter.)
; CHECK-LABEL: define void @object_typeinfo_slot(
; CHECK: cj.store.prev.low
; CHECK: call void @CJ_MCC_StoreBarrierOnHeapField
define void @object_typeinfo_slot(i8* %type, i8 addrspace(1)* %value) gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i64)* @CJ_MCC_NewObject, i32 2, i32 0, i8* %type, i64 24)
  %heap = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  %f = getelementptr i8, i8 addrspace(1)* %heap, i64 0
  %s = bitcast i8 addrspace(1)* %f to i8 addrspace(1)* addrspace(1)*
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %heap, i8 addrspace(1)* addrspace(1)* %s, i32 1)
  ret void
}

; An intervening safepoint (for example a call that may publish the object
; and let the collector flip phases) invalidates the fresh-allocation fact.
; CHECK-LABEL: define void @object_safepoint(
; CHECK: cj.store.prev.low
; CHECK: call void @CJ_MCC_StoreBarrierOnHeapField
define void @object_safepoint(i8* %type, i8 addrspace(1)* %value) gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i64)* @CJ_MCC_NewObject, i32 2, i32 0, i8* %type, i64 24)
  %heap = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  %point = call token (...) @llvm.cj.gc.statepoint(i64 1, i32 0, void ()* @safepoint, i32 0, i32 0)
  %f = getelementptr i8, i8 addrspace(1)* %heap, i64 8
  %s = bitcast i8 addrspace(1)* %f to i8 addrspace(1)* addrspace(1)*
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %heap, i8 addrspace(1)* addrspace(1)* %s, i32 1)
  ret void
}

; A non-allocation (possibly escaped, possibly old) object: nonnull base and
; a constant non-inbounds offset alone prove nothing.
; CHECK-LABEL: define void @existing_object(
; CHECK: cj.store.prev.low
; CHECK: call void @CJ_MCC_StoreBarrierOnHeapField
define void @existing_object(i8 addrspace(1)* nonnull %obj, i8 addrspace(1)* %value) gc "cangjie" {
entry:
  %f = getelementptr i8, i8 addrspace(1)* %obj, i64 8
  %s = bitcast i8 addrspace(1)* %f to i8 addrspace(1)* addrspace(1)*
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %obj, i8 addrspace(1)* addrspace(1)* %s, i32 1)
  ret void
}

; Array TypeInfo through an internal alias: inbounds element store elided.
; CHECK-LABEL: define void @array_alias_inbounds(
; CHECK-NOT: cj.store.prev.low
; CHECK-NOT: CJ_MCC_StoreBarrierOnHeapField
; CHECK: store volatile i64 %cj.store.colored
; CHECK: ret void
define void @array_alias_inbounds(i8 addrspace(1)* %value) gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i64, i64)* @CJ_MCC_NewArray, i32 3, i32 0, i8* bitcast (%ati* @array_ti_alias to i8*), i64 2, i64 poison)
  %heap = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  %f = getelementptr inbounds i8, i8 addrspace(1)* %heap, i64 16
  %s = bitcast i8 addrspace(1)* %f to i8 addrspace(1)* addrspace(1)*
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %heap, i8 addrspace(1)* addrspace(1)* %s, i32 1)
  ret void
}

; Alias TypeInfo plus non-inbounds element offsets, as the constant DIGITS
; initializer emits: both elements of the 2-element array are elided.
; CHECK-LABEL: define void @array_alias_noninbounds(
; CHECK-NOT: cj.store.prev.low
; CHECK-NOT: CJ_MCC_StoreBarrierOnHeapField
; CHECK: store volatile i64 %cj.store.colored
; CHECK-NOT: cj.store.prev.low
; CHECK: store volatile i64 %cj.store.colored
; CHECK: ret void
define void @array_alias_noninbounds(i8 addrspace(1)* %value) gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i64, i64)* @CJ_MCC_NewArray, i32 3, i32 0, i8* bitcast (%ati* @array_ti_alias to i8*), i64 2, i64 poison)
  %heap = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  %f16 = getelementptr i8, i8 addrspace(1)* %heap, i64 16
  %s16 = bitcast i8 addrspace(1)* %f16 to i8 addrspace(1)* addrspace(1)*
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %heap, i8 addrspace(1)* addrspace(1)* %s16, i32 1)
  %f24 = getelementptr i8, i8 addrspace(1)* %heap, i64 24
  %s24 = bitcast i8 addrspace(1)* %f24 to i8 addrspace(1)* addrspace(1)*
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %heap, i8 addrspace(1)* addrspace(1)* %s24, i32 1)
  ret void
}

; Element [32, 40) ends past the 2-element extent (16 + 2 * 8): full barrier.
; CHECK-LABEL: define void @array_alias_past_end(
; CHECK: cj.store.prev.low
; CHECK: call void @CJ_MCC_StoreBarrierOnHeapField
define void @array_alias_past_end(i8 addrspace(1)* %value) gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i64, i64)* @CJ_MCC_NewArray, i32 3, i32 0, i8* bitcast (%ati* @array_ti_alias to i8*), i64 2, i64 poison)
  %heap = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  %f = getelementptr i8, i8 addrspace(1)* %heap, i64 32
  %s = bitcast i8 addrspace(1)* %f to i8 addrspace(1)* addrspace(1)*
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %heap, i8 addrspace(1)* addrspace(1)* %s, i32 1)
  ret void
}

; The array length field (offset 8) is header, not an element slot.
; CHECK-LABEL: define void @array_alias_length_slot(
; CHECK: cj.store.prev.low
; CHECK: call void @CJ_MCC_StoreBarrierOnHeapField
define void @array_alias_length_slot(i8 addrspace(1)* %value) gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i64, i64)* @CJ_MCC_NewArray, i32 3, i32 0, i8* bitcast (%ati* @array_ti_alias to i8*), i64 2, i64 poison)
  %heap = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  %f = getelementptr i8, i8 addrspace(1)* %heap, i64 8
  %s = bitcast i8 addrspace(1)* %f to i8 addrspace(1)* addrspace(1)*
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %heap, i8 addrspace(1)* addrspace(1)* %s, i32 1)
  ret void
}

; A weak alias may be interposed at link time by a different TypeInfo, so
; its initializer bounds nothing (stripPointerCastsAndAliases would follow it).
; CHECK-LABEL: define void @array_weak_alias(
; CHECK: cj.store.prev.low
; CHECK: call void @CJ_MCC_StoreBarrierOnHeapField
define void @array_weak_alias(i8 addrspace(1)* %value) gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i64, i64)* @CJ_MCC_NewArray, i32 3, i32 0, i8* bitcast (%ati* @array_ti_weak to i8*), i64 2, i64 poison)
  %heap = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  %f = getelementptr inbounds i8, i8 addrspace(1)* %heap, i64 16
  %s = bitcast i8 addrspace(1)* %f to i8 addrspace(1)* addrspace(1)*
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %heap, i8 addrspace(1)* addrspace(1)* %s, i32 1)
  ret void
}

; 16 + 8191 * 8 = 65544 > 64 KiB: segmented initialization may yield and the
; runtime skips on_slowpath_allocation_exit, so no allocation dominator.
; CHECK-LABEL: define void @array_alias_too_large(
; CHECK: cj.store.prev.low
; CHECK: call void @CJ_MCC_StoreBarrierOnHeapField
define void @array_alias_too_large(i8 addrspace(1)* %value) gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i64, i64)* @CJ_MCC_NewArray, i32 3, i32 0, i8* bitcast (%ati* @array_ti_alias to i8*), i64 8191, i64 poison)
  %heap = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  %f = getelementptr i8, i8 addrspace(1)* %heap, i64 16
  %s = bitcast i8 addrspace(1)* %f to i8 addrspace(1)* addrspace(1)*
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %heap, i8 addrspace(1)* addrspace(1)* %s, i32 1)
  ret void
}

; After a safepoint the store keeps its full barrier, but the slot is still a
; proven in-extent heap slot of a bounded array: no reserved-range test.
; CHECK-LABEL: define void @array_alias_safepoint_domain(
; CHECK-NOT: cj.store.inheap
; CHECK: cj.store.prev.low
; CHECK: call void @CJ_MCC_StoreBarrierOnHeapField
define void @array_alias_safepoint_domain(i8 addrspace(1)* %value) gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i64, i64)* @CJ_MCC_NewArray, i32 3, i32 0, i8* bitcast (%ati* @array_ti_alias to i8*), i64 2, i64 poison)
  %heap = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  %point = call token (...) @llvm.cj.gc.statepoint(i64 1, i32 0, void ()* @safepoint, i32 0, i32 0)
  %f = getelementptr i8, i8 addrspace(1)* %heap, i64 16
  %s = bitcast i8 addrspace(1)* %f to i8 addrspace(1)* addrspace(1)*
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %heap, i8 addrspace(1)* addrspace(1)* %s, i32 1)
  ret void
}

declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i64)
declare i8 addrspace(1)* @CJ_MCC_NewArray(i8*, i64, i64)
declare token @llvm.cj.gc.statepoint(...)
declare i8 addrspace(1)* @llvm.cj.gc.result(token)
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)
declare void @safepoint()
