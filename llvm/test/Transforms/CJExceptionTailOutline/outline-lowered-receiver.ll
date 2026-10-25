; RUN: opt -passes='cj-runtime-lowering,cj-exception-tail-outline' -verify-each -S < %s | FileCheck %s
; RUN: opt -passes='cj-runtime-lowering,cj-exception-tail-outline' -enable-cangjie-exception-tail-extract=false -verify-each -S < %s | FileCheck %s --check-prefix=OFF
;
; Start at the real allocation intrinsic: runtime lowering creates NewObject
; with noalias on the call AND declaration before exception tail extraction.
; Do not replace this producer with only an attribute-free hand-written call.
target triple = "x86_64-unknown-linux-gnu"
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }
@TI = external global %TypeInfo

declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare i8 addrspace(1)* @ctor(i8 addrspace(1)*, %TypeInfo*)
declare void @CJ_MCC_ThrowException(i8 addrspace(1)*)

; CHECK-LABEL: define void @lowered_updated_receiver(
; CHECK-NEXT: call void @"__cj$exception_tail_helper0_ref_alloc_noalias"(i8* bitcast (%TypeInfo* @TI to i8*), i32 [[SIZE:[0-9]+]], i8 addrspace(1)* (i8 addrspace(1)*, %TypeInfo*)* @ctor, %TypeInfo* @TI)
; CHECK-NEXT: unreachable
; OFF-LABEL: define void @lowered_updated_receiver(
; OFF-NEXT: %obj = call noalias i8 addrspace(1)* @CJ_MCC_NewObject
; OFF-NEXT: %updated = call i8 addrspace(1)* @ctor
; OFF-NEXT: call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
define void @lowered_updated_receiver() gc "cangjie" {
  %obj = call noalias i8 addrspace(1)* @llvm.cj.malloc.object(i8* bitcast (%TypeInfo* @TI to i8*), i32 32), !TrustedSize !0
  %updated = call i8 addrspace(1)* @ctor(i8 addrspace(1)* %obj, %TypeInfo* @TI)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
  unreachable
}
; CHECK: declare noalias i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
; CHECK-LABEL: define internal void @"__cj$exception_tail_helper0_ref_alloc_noalias"(
; CHECK: %obj = call noalias i8 addrspace(1)* @CJ_MCC_NewObject(i8* %alloc_ti, i32 %alloc_size)
; CHECK-NEXT: [[RESULT:%.*]] = call i8 addrspace(1)* %ctor(i8 addrspace(1)* %obj, %TypeInfo* %ctor_ti)
; CHECK-NEXT: call void @CJ_MCC_ThrowException(i8 addrspace(1)* [[RESULT]])
; CHECK-NEXT: unreachable
; OFF-NOT: define internal void @"__cj$exception_tail_helper
!0 = !{}
