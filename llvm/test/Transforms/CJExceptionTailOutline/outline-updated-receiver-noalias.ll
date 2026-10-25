; RUN: opt -passes='cj-exception-tail-outline,cj-exception-tail-outline' -verify-each -S < %s | FileCheck %s
; RUN: opt -passes=cj-exception-tail-outline -enable-cangjie-exception-tail-extract=false -verify-each -S < %s | FileCheck %s --check-prefix=OFF
;
; Formal producer contract: C IRBuilder malloc + CJRuntimeLowering marks both
; NewObject's declaration and its call noalias. Constructor return is not fresh:
; it is the possibly updated receiver, so do not add noalias to that call.
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
@allocation = external global %TypeInfo
@constructor = external global %TypeInfo

declare noalias i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare i8 addrspace(1)* @ctor(i8 addrspace(1)*, %TypeInfo*)
declare i8 addrspace(1)* @ctor_msg(i8 addrspace(1)*, %"record.std.core:String"*, %TypeInfo*)
declare void @CJ_MCC_ThrowException(i8 addrspace(1)*)

; CHECK-LABEL: define void @formal_updated_receiver(
; CHECK-NEXT: call void @"__cj$exception_tail_helper0_ref_alloc_noalias"(i8* bitcast (%TypeInfo* @allocation to i8*), i32 73, i8 addrspace(1)* (i8 addrspace(1)*, %TypeInfo*)* @ctor, %TypeInfo* @constructor)
; CHECK-NEXT: unreachable
; OFF-LABEL: define void @formal_updated_receiver(
; OFF-NEXT: %obj = call noalias i8 addrspace(1)* @CJ_MCC_NewObject
; OFF-NEXT: %updated = call i8 addrspace(1)* @ctor
; OFF-NEXT: call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
define void @formal_updated_receiver() gc "cangjie" {
  %obj = call noalias i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @allocation to i8*), i32 73)
  %updated = call i8 addrspace(1)* @ctor(i8 addrspace(1)* %obj, %TypeInfo* @constructor)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
  unreachable
}

; CHECK-LABEL: define void @formal_updated_string(
; CHECK-NEXT: call void @"__cj$exception_tail_helper_string_ref_alloc_noalias"(i8* bitcast (%TypeInfo* @allocation to i8*), i32 91, i8 addrspace(1)* (i8 addrspace(1)*, %"record.std.core:String"*, %TypeInfo*)* @ctor_msg, %TypeInfo* poison, %"record.std.core:String"* %msg)
; CHECK-NEXT: unreachable
define void @formal_updated_string(%"record.std.core:String"* %msg) gc "cangjie" {
  %obj = call noalias i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @allocation to i8*), i32 91)
  %updated = call i8 addrspace(1)* @ctor_msg(i8 addrspace(1)* %obj, %"record.std.core:String"* %msg, %TypeInfo* poison)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
  unreachable
}

; A declaration-only promise stays on the callee; do not invent a call attribute.
; CHECK-LABEL: define void @declaration_only(
; CHECK-NEXT: call void @"__cj$exception_tail_helper0_ref"(
; CHECK-NEXT: unreachable
define void @declaration_only() gc "cangjie" {
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @allocation to i8*), i32 73)
  %updated = call i8 addrspace(1)* @ctor(i8 addrspace(1)* %obj, %TypeInfo* @constructor)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
  unreachable
}

; Other allocation return and parameter attributes remain ineligible. A generic
; relaxation of hasOrdinaryCallABI would move these calls and lose promises.
; CHECK-LABEL: define void @allocation_extra_return(
; CHECK-NEXT: %obj = call noalias noundef i8 addrspace(1)* @CJ_MCC_NewObject
; CHECK-NEXT: %updated = call i8 addrspace(1)* @ctor
; CHECK-NEXT: call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
define void @allocation_extra_return() gc "cangjie" {
  %obj = call noalias noundef i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @allocation to i8*), i32 73)
  %updated = call i8 addrspace(1)* @ctor(i8 addrspace(1)* %obj, %TypeInfo* @constructor)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
  unreachable
}
; CHECK-LABEL: define void @allocation_parameter(
; CHECK-NEXT: %obj = call noalias i8 addrspace(1)* @CJ_MCC_NewObject(i8* nonnull
; CHECK-NEXT: %updated = call i8 addrspace(1)* @ctor
; CHECK-NEXT: call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
define void @allocation_parameter() gc "cangjie" {
  %obj = call noalias i8 addrspace(1)* @CJ_MCC_NewObject(i8* nonnull bitcast (%TypeInfo* @allocation to i8*), i32 73)
  %updated = call i8 addrspace(1)* @ctor(i8 addrspace(1)* %obj, %TypeInfo* @constructor)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
  unreachable
}

; CHECK-LABEL: define internal void @"__cj$exception_tail_helper0_ref_alloc_noalias"(
; CHECK: %obj = call noalias i8 addrspace(1)* @CJ_MCC_NewObject(i8* %alloc_ti, i32 %alloc_size)
; CHECK-NEXT: [[RESULT:%.*]] = call i8 addrspace(1)* %ctor(i8 addrspace(1)* %obj, %TypeInfo* %ctor_ti)
; CHECK-NEXT: call void @CJ_MCC_ThrowException(i8 addrspace(1)* [[RESULT]])
; CHECK-NEXT: unreachable
; CHECK-LABEL: define internal void @"__cj$exception_tail_helper_string_ref_alloc_noalias"(
; CHECK: %obj = call noalias i8 addrspace(1)* @CJ_MCC_NewObject(i8* %alloc_ti, i32 %alloc_size)
; CHECK-NEXT: [[MSGRESULT:%.*]] = call i8 addrspace(1)* %ctor(i8 addrspace(1)* %obj, %"record.std.core:String"* %msg, %TypeInfo* %ctor_ti)
; CHECK-NEXT: call void @CJ_MCC_ThrowException(i8 addrspace(1)* [[MSGRESULT]])
; CHECK-NEXT: unreachable
; CHECK-LABEL: define internal void @"__cj$exception_tail_helper0_ref"(
; CHECK: %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* %alloc_ti, i32 %alloc_size)
; CHECK-NEXT: [[DECLRESULT:%.*]] = call i8 addrspace(1)* %ctor(i8 addrspace(1)* %obj, %TypeInfo* %ctor_ti)
; CHECK-NEXT: call void @CJ_MCC_ThrowException(i8 addrspace(1)* [[DECLRESULT]])
; OFF-NOT: define internal void @"__cj$exception_tail_helper
