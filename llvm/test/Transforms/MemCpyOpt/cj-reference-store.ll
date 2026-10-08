; RUN: opt -S -passes='cj-gcinstr-replace,memcpyopt,cj-gcinstr-restore,verify' %s -o %t
; RUN: FileCheck %s < %t
; RUN: llc --cangjie-pipeline -mtriple=x86_64 %t -o - | FileCheck %s --check-prefix=ASM
;
; Extracted from HashMap<String,ASTContext>.clear: existing AS1 heap slots,
; two null references separated by two primitive zeros. A null value still
; needs the old-value store barrier and colored-null publication (ZGC
; zBarrierSet.inline.hpp:349-359). Both the first store and stores reached
; from a primitive store / memset must retain their reference shape.
; Unknown strength is protected without relying on GC_Write_Ref_IID metadata.
target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)
declare void @llvm.memset.p1i8.i64(i8 addrspace(1)* nocapture writeonly, i8, i64, i1 immarg)

; CHECK-LABEL: define void @two_refs(
; CHECK: call void {{.*}}@llvm.cj.gcwrite.ref(i8 addrspace(1)* null, {{.*}}i32 1)
; CHECK: call void {{.*}}@llvm.cj.gcwrite.ref(i8 addrspace(1)* null, {{.*}}i32 1)
; CHECK-NOT: @llvm.cj.gcwrite.ref
; CHECK: ret void
; ASM-LABEL: two_refs:
; ASM-DAG: CJ_MCC_WriteRefField_Strong
; ASM-DAG: CJ_MCC_StoreBarrierOnHeapField@PLT
define void @two_refs(i8 addrspace(1)* %base) gc "cangjie" {
  %r0 = getelementptr i8, i8 addrspace(1)* %base, i64 0
  %p0 = bitcast i8 addrspace(1)* %r0 to i8 addrspace(1)* addrspace(1)*
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* null, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %p0, i32 1)
  %b8 = getelementptr i8, i8 addrspace(1)* %base, i64 8
  %i8 = bitcast i8 addrspace(1)* %b8 to i32 addrspace(1)*
  store i32 0, i32 addrspace(1)* %i8, align 4
  %b12 = getelementptr i8, i8 addrspace(1)* %base, i64 12
  %i12 = bitcast i8 addrspace(1)* %b12 to i32 addrspace(1)*
  store i32 0, i32 addrspace(1)* %i12, align 4
  %r16 = getelementptr i8, i8 addrspace(1)* %base, i64 16
  %p16 = bitcast i8 addrspace(1)* %r16 to i8 addrspace(1)* addrspace(1)*
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* null, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %p16, i32 1)
  ret void
}

; CHECK-LABEL: define void @primitive_then_ref(
; CHECK: call void {{.*}}@llvm.cj.gcwrite.ref(i8 addrspace(1)* null, {{.*}}i32 1)
; CHECK-NOT: @llvm.cj.gcwrite.ref
; CHECK: ret void
; ASM-LABEL: primitive_then_ref:
; ASM-DAG: CJ_MCC_WriteRefField_Strong
; ASM-DAG: CJ_MCC_StoreBarrierOnHeapField@PLT
define void @primitive_then_ref(i8 addrspace(1)* %base) gc "cangjie" {
  %b0 = getelementptr i8, i8 addrspace(1)* %base, i64 0
  %i0 = bitcast i8 addrspace(1)* %b0 to i64 addrspace(1)*
  store i64 0, i64 addrspace(1)* %i0, align 4
  %b8 = getelementptr i8, i8 addrspace(1)* %base, i64 8
  %i8 = bitcast i8 addrspace(1)* %b8 to i64 addrspace(1)*
  store i64 0, i64 addrspace(1)* %i8, align 4
  %b16 = getelementptr i8, i8 addrspace(1)* %base, i64 16
  %i16 = bitcast i8 addrspace(1)* %b16 to i64 addrspace(1)*
  store i64 0, i64 addrspace(1)* %i16, align 4
  %r24 = getelementptr i8, i8 addrspace(1)* %base, i64 24
  %p24 = bitcast i8 addrspace(1)* %r24 to i8 addrspace(1)* addrspace(1)*
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* null, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %p24, i32 1)
  ret void
}

; CHECK-LABEL: define void @memset_then_ref(
; CHECK: call void {{.*}}@llvm.cj.gcwrite.ref(i8 addrspace(1)* null, {{.*}}i32 2)
; CHECK-NOT: @llvm.cj.gcwrite.ref
; CHECK: ret void
; ASM-LABEL: memset_then_ref:
; ASM-DAG: CJ_MCC_WriteRefField_Weak
; ASM-DAG: CJ_MCC_StoreBarrierOnHeapFieldNoKeepAlive
define void @memset_then_ref(i8 addrspace(1)* %base) gc "cangjie" {
  call void @llvm.memset.p1i8.i64(i8 addrspace(1)* align 8 %base, i8 0, i64 24, i1 false)
  %r24 = getelementptr i8, i8 addrspace(1)* %base, i64 24
  %p24 = bitcast i8 addrspace(1)* %r24 to i8 addrspace(1)* addrspace(1)*
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* null, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %p24, i32 2)
  ret void
}

; CHECK-LABEL: define void @unknown_then_primitive(
; CHECK: call void {{.*}}@llvm.cj.gcwrite.ref(i8 addrspace(1)* null, {{.*}}{{%p[0-9]+}})
; CHECK-NOT: @llvm.cj.gcwrite.ref
; CHECK: ret void
; ASM-LABEL: unknown_then_primitive:
; ASM: CJ_MCC_WriteRefField{{(@PLT)?$}}
define void @unknown_then_primitive(i8 addrspace(1)* %base) gc "cangjie" {
  %r0 = getelementptr i8, i8 addrspace(1)* %base, i64 0
  %p0 = bitcast i8 addrspace(1)* %r0 to i8 addrspace(1)* addrspace(1)*
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* null, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %p0)
  %b8 = getelementptr i8, i8 addrspace(1)* %base, i64 8
  %i8 = bitcast i8 addrspace(1)* %b8 to i64 addrspace(1)*
  store i64 0, i64 addrspace(1)* %i8, align 4
  %b16 = getelementptr i8, i8 addrspace(1)* %base, i64 16
  %i16 = bitcast i8 addrspace(1)* %b16 to i64 addrspace(1)*
  store i64 0, i64 addrspace(1)* %i16, align 4
  ret void
}

; CHECK-LABEL: define void @typed_without_metadata(
; CHECK: call void {{.*}}@llvm.cj.gcwrite.ref(i8 addrspace(1)* null, {{.*}}{{%p[0-9]+}})
; CHECK: call void {{.*}}@llvm.cj.gcwrite.ref(i8 addrspace(1)* null, {{.*}}{{%p[0-9]+}})
; CHECK-NOT: @llvm.cj.gcwrite.ref
; CHECK: ret void
; ASM-LABEL: typed_without_metadata:
; ASM: CJ_MCC_WriteRefField{{(@PLT)?$}}
define void @typed_without_metadata(i8 addrspace(1)* %base) gc "cangjie" {
  %r0 = getelementptr i8, i8 addrspace(1)* %base, i64 0
  %p0 = bitcast i8 addrspace(1)* %r0 to i8 addrspace(1)* addrspace(1)*
  store i8 addrspace(1)* null, i8 addrspace(1)* addrspace(1)* %p0, align 8
  %b8 = getelementptr i8, i8 addrspace(1)* %base, i64 8
  %i8 = bitcast i8 addrspace(1)* %b8 to i32 addrspace(1)*
  store i32 0, i32 addrspace(1)* %i8, align 4
  %b12 = getelementptr i8, i8 addrspace(1)* %base, i64 12
  %i12 = bitcast i8 addrspace(1)* %b12 to i32 addrspace(1)*
  store i32 0, i32 addrspace(1)* %i12, align 4
  %r16 = getelementptr i8, i8 addrspace(1)* %base, i64 16
  %p16 = bitcast i8 addrspace(1)* %r16 to i8 addrspace(1)* addrspace(1)*
  store i8 addrspace(1)* null, i8 addrspace(1)* addrspace(1)* %p16, align 8
  ret void
}

; CHECK-LABEL: define void @pure_primitive(
; CHECK: call void @llvm.memset.p1i8.i64({{.*}}i64 24, i1 false)
; CHECK-NOT: @llvm.cj.gcwrite.ref
; CHECK: ret void
; ASM-LABEL: pure_primitive:
; ASM-NOT: CJ_MCC_
; ASM: retq
define void @pure_primitive(i8 addrspace(1)* %base) gc "cangjie" {
  %b0 = getelementptr i8, i8 addrspace(1)* %base, i64 0
  %i0 = bitcast i8 addrspace(1)* %b0 to i32 addrspace(1)*
  store i32 0, i32 addrspace(1)* %i0, align 4
  %b4 = getelementptr i8, i8 addrspace(1)* %base, i64 4
  %i4 = bitcast i8 addrspace(1)* %b4 to i32 addrspace(1)*
  store i32 0, i32 addrspace(1)* %i4, align 4
  %b8 = getelementptr i8, i8 addrspace(1)* %base, i64 8
  %i8 = bitcast i8 addrspace(1)* %b8 to i32 addrspace(1)*
  store i32 0, i32 addrspace(1)* %i8, align 4
  %b12 = getelementptr i8, i8 addrspace(1)* %base, i64 12
  %i12 = bitcast i8 addrspace(1)* %b12 to i32 addrspace(1)*
  store i32 0, i32 addrspace(1)* %i12, align 4
  %b16 = getelementptr i8, i8 addrspace(1)* %base, i64 16
  %i16 = bitcast i8 addrspace(1)* %b16 to i32 addrspace(1)*
  store i32 0, i32 addrspace(1)* %i16, align 4
  %b20 = getelementptr i8, i8 addrspace(1)* %base, i64 20
  %i20 = bitcast i8 addrspace(1)* %b20 to i32 addrspace(1)*
  store i32 0, i32 addrspace(1)* %i20, align 4
  ret void
}
