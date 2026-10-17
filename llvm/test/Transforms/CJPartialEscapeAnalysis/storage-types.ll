; RUN: opt -opaque-pointers=0 -passes=cj-pea -S %s | FileCheck %s
; RUN: opt -opaque-pointers=1 -passes=cj-pea -S %s | FileCheck %s
;
; Exercise the complete PEA pass in both pointer modes. A global reference
; publication must retain a heap object, while known scalar storage permits
; stack allocation. Array rewriting must get GEP types from its operations.

target datalayout = "e-p:64:64-p1:64:64-i64:64-n8:16:32:64"
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, %TypeInfo*, i8*, i8* }
%ObjLayout.Test = type { i64 }
%ArrayBase = type { i64 }
%ArrayLayout.Test = type { %ArrayBase, [0 x i64] }

@ti = external global %TypeInfo, !RelatedType !0
@array_ti = external global %TypeInfo, !RelatedType !1
@slot = global i8 addrspace(1)* null
@alias = alias i8 addrspace(1)*, i8 addrspace(1)** @slot
@plain = global [1 x i64] zeroinitializer

declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare i8 addrspace(1)* @CJ_MCC_NewArray(i8*, i64)
declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1 immarg)

define void @publish_global() gc "cangjie" {
; CHECK-LABEL: define void @publish_global(
; CHECK-NOT: alloca
; CHECK: @CJ_MCC_NewObject(
; CHECK: store {{.*}} @slot
; CHECK: ret void
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @ti to i8*), i32 16)
  store i8 addrspace(1)* %obj, i8 addrspace(1)** @slot
  ret void
}

define void @publish_alias() gc "cangjie" {
; CHECK-LABEL: define void @publish_alias(
; CHECK-NOT: alloca
; CHECK: @CJ_MCC_NewObject(
; CHECK: store {{.*}} @alias
; CHECK: ret void
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @ti to i8*), i32 16)
  store i8 addrspace(1)* %obj, i8 addrspace(1)** @alias
  ret void
}

define void @copy_scalar() gc "cangjie" {
; CHECK-LABEL: define void @copy_scalar(
; CHECK: alloca { {{.*}}%ObjLayout.Test }
; CHECK-NOT: @CJ_MCC_NewObject(
; CHECK: @llvm.memcpy
; CHECK: ret void
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @ti to i8*), i32 16)
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %obj, i8* bitcast ([1 x i64]* @plain to i8*), i64 8, i1 false)
  ret void
}

define void @copy_unknown() gc "cangjie" {
; CHECK-LABEL: define void @copy_unknown(
; CHECK-NOT: alloca
; CHECK: @CJ_MCC_NewObject(
; CHECK: @llvm.memcpy
; CHECK: ret void
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @ti to i8*), i32 16)
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %obj, i8* inttoptr (i64 4096 to i8*), i64 8, i1 false)
  ret void
}

define void @allocate_array() gc "cangjie" {
; CHECK-LABEL: define void @allocate_array(
; CHECK: alloca { {{.*}}{ %ArrayBase, [2 x i64] } }
; CHECK: store i64 2,
; CHECK-NOT: @CJ_MCC_NewArray(
; CHECK: ret void
  %arr = call i8 addrspace(1)* @CJ_MCC_NewArray(i8* bitcast (%TypeInfo* @array_ti to i8*), i64 2)
  ret void
}

!0 = !{!"ObjLayout.Test"}
!1 = !{!"ArrayLayout.Test"}
