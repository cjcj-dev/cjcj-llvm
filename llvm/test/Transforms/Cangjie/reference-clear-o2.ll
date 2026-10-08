; RUN: opt --cangjie-pipeline --only-verify-out -S -passes='default<O2>' %s -o %t
; RUN: FileCheck %s < %t
; RUN: llc --cangjie-pipeline -mtriple=x86_64 %t -o - | FileCheck %s --check-prefix=ASM
;
; The complete optimizing pipeline, starting from a real aggregate write,
; not a hand-written Replace output. The first layout is the exact 40-byte
; HashMap<String,ASTContext>.clear entry (refs at 16 and 32); the second
; changes offsets and primitive gap/trailer so protection is not size-specific.
; ZGC value_copy_in_heap, zBarrierSet.inline.hpp:473-510, separates primitive
; payload from oop stores; oop_clear_one:349-359 still barriers null.
target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
%String = type { i8 addrspace(1)*, i32, i32 }
%Entry40 = type { i64, i64, %String, i8 addrspace(1)* }
%Entry48 = type { i64, i8 addrspace(1)*, [4 x i32], i8 addrspace(1)*, i64 }
declare void @llvm.cj.memset.p0i8(i8*, i8, i64, i1 immarg)
declare void @llvm.cj.gcwrite.struct.p0i8.i64(i8 addrspace(1)*, i8 addrspace(1)*, i8*, i64)

; CHECK-LABEL: define void @clear_entry40(
; CHECK: call void {{.*}}@llvm.cj.gcwrite.ref(i8 addrspace(1)* null, {{.*}}i32 1)
; CHECK: call void {{.*}}@llvm.cj.gcwrite.ref(i8 addrspace(1)* null, {{.*}}i32 1)
; CHECK-NOT: @llvm.cj.gcwrite.ref
; CHECK: ret void
; ASM-LABEL: clear_entry40:
; ASM: CJ_MCC_WriteRefField_Strong
; ASM: movq 96(%r15), [[OLD_DATA40_0:%[a-z0-9]+]]
; ASM: movzwl ([[SLOT40_0:%[a-z0-9]+]]), [[OLD40_0:%[a-z0-9]+]]
; ASM-NEXT: testl [[OLD40_0]], 32([[OLD_DATA40_0]])
; ASM: CJ_MCC_StoreBarrierOnHeapField@PLT
; ASM: movq 96(%r15), [[GOOD_DATA40_0:%[a-z0-9]+]]
; ASM: orq 24([[GOOD_DATA40_0]]), [[COLORED40_0:%[a-z0-9]+]]
; ASM-NEXT: movq [[COLORED40_0]], ([[SLOT40_0]])
; ASM: CJ_MCC_WriteRefField_Strong
; ASM: movq 96(%r15), [[OLD_DATA40_1:%[a-z0-9]+]]
; ASM: movzwl ([[SLOT40_1:%[a-z0-9]+]]), [[OLD40_1:%[a-z0-9]+]]
; ASM-NEXT: testl [[OLD40_1]], 32([[OLD_DATA40_1]])
; ASM: CJ_MCC_StoreBarrierOnHeapField@PLT
; ASM: movq 96(%r15), [[GOOD_DATA40_1:%[a-z0-9]+]]
; ASM: orq 24([[GOOD_DATA40_1]]), [[COLORED40_1:%[a-z0-9]+]]
; ASM-NEXT: movq [[COLORED40_1]], ([[SLOT40_1]])
define void @clear_entry40(i8 addrspace(1)* %base) gc "cangjie" {
  %source = alloca %Entry40, align 8
  %src = bitcast %Entry40* %source to i8*
  call void @llvm.cj.memset.p0i8(i8* align 8 %src, i8 0, i64 40, i1 false)
  store %Entry40 zeroinitializer, %Entry40* %source, align 8
  call void @llvm.cj.gcwrite.struct.p0i8.i64(i8 addrspace(1)* %base, i8 addrspace(1)* %base, i8* %src, i64 40)
  ret void
}

; CHECK-LABEL: define void @clear_entry48(
; CHECK: call void {{.*}}@llvm.cj.gcwrite.ref(i8 addrspace(1)* null, {{.*}}i32 1)
; CHECK: call void {{.*}}@llvm.cj.gcwrite.ref(i8 addrspace(1)* null, {{.*}}i32 1)
; CHECK-NOT: @llvm.cj.gcwrite.ref
; CHECK: ret void
; ASM-LABEL: clear_entry48:
; ASM: CJ_MCC_WriteRefField_Strong
; ASM: movq 96(%r15), [[OLD_DATA48_0:%[a-z0-9]+]]
; ASM: movzwl ([[SLOT48_0:%[a-z0-9]+]]), [[OLD48_0:%[a-z0-9]+]]
; ASM-NEXT: testl [[OLD48_0]], 32([[OLD_DATA48_0]])
; ASM: CJ_MCC_StoreBarrierOnHeapField@PLT
; ASM: movq 96(%r15), [[GOOD_DATA48_0:%[a-z0-9]+]]
; ASM: orq 24([[GOOD_DATA48_0]]), [[COLORED48_0:%[a-z0-9]+]]
; ASM-NEXT: movq [[COLORED48_0]], ([[SLOT48_0]])
; ASM: CJ_MCC_WriteRefField_Strong
; ASM: movq 96(%r15), [[OLD_DATA48_1:%[a-z0-9]+]]
; ASM: movzwl ([[SLOT48_1:%[a-z0-9]+]]), [[OLD48_1:%[a-z0-9]+]]
; ASM-NEXT: testl [[OLD48_1]], 32([[OLD_DATA48_1]])
; ASM: CJ_MCC_StoreBarrierOnHeapField@PLT
; ASM: movq 96(%r15), [[GOOD_DATA48_1:%[a-z0-9]+]]
; ASM: orq 24([[GOOD_DATA48_1]]), [[COLORED48_1:%[a-z0-9]+]]
; ASM-NEXT: movq [[COLORED48_1]], ([[SLOT48_1]])
define void @clear_entry48(i8 addrspace(1)* %base) gc "cangjie" {
  %source = alloca %Entry48, align 8
  %src = bitcast %Entry48* %source to i8*
  call void @llvm.cj.memset.p0i8(i8* align 8 %src, i8 0, i64 48, i1 false)
  store %Entry48 zeroinitializer, %Entry48* %source, align 8
  call void @llvm.cj.gcwrite.struct.p0i8.i64(i8 addrspace(1)* %base, i8 addrspace(1)* %base, i8* %src, i64 48)
  ret void
}
