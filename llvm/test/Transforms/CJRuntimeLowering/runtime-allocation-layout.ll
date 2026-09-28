; RUN: opt -passes=cj-runtime-lowering -enable-cangjie-new-array-fastpath -S < %s | FileCheck %s
; RUN: opt -cj-runtime-lowering -enable-cangjie-new-array-fastpath -S < %s | FileCheck %s

target datalayout = "e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, i8**, i8*, i8* }
%Element = type { i64 }
%Empty = type {}
%ArrayLayout.full = type { i64, [0 x %Element] }
%ArrayLayout.empty = type { i64, [0 x %Empty] }
@Array.ti = constant %TypeInfo { i8* null, i8 -126, i8 0, i16 0, i32 8, i8* null, i32 0, i8 8, i8 0, i16 0, i32* null, i8* null, i8* null, i8* null, %TypeInfo* null, i8** null, i8* null, i8* null }, !RelatedType !1
@Empty.ti = constant %TypeInfo { i8* null, i8 -126, i8 0, i16 0, i32 0, i8* null, i32 0, i8 1, i8 0, i16 0, i32* null, i8* null, i8* null, i8* null, %TypeInfo* null, i8** null, i8* null, i8* null }, !RelatedType !2


; CHECK-LABEL: define i8 addrspace(1)* @object_constant(
; CHECK: call {{.*}}@CJ_MCC_NewObject(i8* %ti, i32 24)
define i8 addrspace(1)* @object_constant(i8* %ti) {
  %p = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* %ti, i32 9), !TrustedSize !0
  ret i8 addrspace(1)* %p
}
; CHECK-LABEL: define i8 addrspace(1)* @object_dynamic(
; CHECK: getelementptr i8, i8* %ti, i32 12
; CHECK: %[[SIZE:.*]] = load i32,
; CHECK: %[[PAD:.*]] = add i32 %[[SIZE]], 15
; CHECK: %[[ALIGNED:.*]] = and i32 %[[PAD]], -8
; CHECK: call {{.*}}@CJ_MCC_NewObject(i8* %ti, i32 %[[ALIGNED]])
define i8 addrspace(1)* @object_dynamic(i8* %ti) {
  %p = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* %ti, i32 0)
  ret i8 addrspace(1)* %p
}
; CHECK-LABEL: define i8 addrspace(1)* @array_constant(
; CHECK: call {{.*}}@CJ_MCC_NewArray(i8* {{.*}}, i64 3, i64 40)
define i8 addrspace(1)* @array_constant(i8* %ti) {
  %p = call i8 addrspace(1)* @llvm.cj.malloc.array(i8* bitcast (%TypeInfo* @Array.ti to i8*), i64 3, i64 8)
  ret i8 addrspace(1)* %p
}
; CHECK-LABEL: define i8 addrspace(1)* @array_empty_element(
; CHECK: call {{.*}}@CJ_MCC_NewArray(i8* {{.*}}, i64 3, i64 16)
define i8 addrspace(1)* @array_empty_element(i8* %ti) {
  %p = call i8 addrspace(1)* @llvm.cj.malloc.array(i8* bitcast (%TypeInfo* @Empty.ti to i8*), i64 3, i64 0)
  ret i8 addrspace(1)* %p
}
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare i8 addrspace(1)* @llvm.cj.malloc.array(i8*, i64, i64)
!0 = !{}

!1 = !{!"ArrayLayout.full"}
!2 = !{!"ArrayLayout.empty"}
