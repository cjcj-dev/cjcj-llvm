; RUN: opt -passes=cj-pea -S < %s | FileCheck %s

target datalayout = "e-m:e-p:32:32-p1:32:32-i64:64-n32-S64"
target triple = "i386-unknown-linux-gnu"

%BitMap = type { i32, [0 x i8] }
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i32*, i8*, i8*, i8*, %TypeInfo*, i8*, i8* }
%ChildLayout = type { i32 }
%FlatLayout = type { [2 x i8 addrspace(1)*] }
%NestedLayout = type { [2 x [2 x i8 addrspace(1)*]] }

@Child.ti = internal global %TypeInfo zeroinitializer, !RelatedType !0
@Flat.ti = internal global %TypeInfo zeroinitializer, !RelatedType !1
@Nested.ti = internal global %TypeInfo zeroinitializer, !RelatedType !2

declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)*, i8 addrspace(1)*, i8*, i64)

define i8 addrspace(1)* @copy_flat_last() #0 gc "cangjie" {
; CHECK-LABEL: @copy_flat_last(
; CHECK: call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @Child.ti to i8*), i32 12)
entry:
  %src = alloca %FlatLayout, align 4
  %child = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @Child.ti to i8*), i32 12)
  %slot = getelementptr inbounds %FlatLayout, %FlatLayout* %src, i32 0, i32 0, i32 1
  store i8 addrspace(1)* %child, i8 addrspace(1)** %slot, align 4
  %holder = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @Flat.ti to i8*), i32 16)
  %dst = getelementptr inbounds i8, i8 addrspace(1)* %holder, i32 8
  %src.i8 = bitcast %FlatLayout* %src to i8*
  call void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)* %holder, i8 addrspace(1)* %dst, i8* %src.i8, i64 8)
  ret i8 addrspace(1)* %holder
}

define i8 addrspace(1)* @copy_nested_last() #0 gc "cangjie" {
; CHECK-LABEL: @copy_nested_last(
; CHECK: call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @Child.ti to i8*), i32 12)
entry:
  %src = alloca %NestedLayout, align 4
  %child = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @Child.ti to i8*), i32 12)
  %slot = getelementptr inbounds %NestedLayout, %NestedLayout* %src, i32 0, i32 0, i32 1, i32 1
  store i8 addrspace(1)* %child, i8 addrspace(1)** %slot, align 4
  %holder = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @Nested.ti to i8*), i32 24)
  %dst = getelementptr inbounds i8, i8 addrspace(1)* %holder, i32 8
  %src.i8 = bitcast %NestedLayout* %src to i8*
  call void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)* %holder, i8 addrspace(1)* %dst, i8* %src.i8, i64 16)
  ret i8 addrspace(1)* %holder
}

attributes #0 = { "hasMD" }

!0 = !{!"ChildLayout"}
!1 = !{!"FlatLayout"}
!2 = !{!"NestedLayout"}
