; RUN: opt -passes=cj-exception-tail-outline -verify-each -S < %s | FileCheck %s
; RUN: opt -passes='cj-exception-tail-outline,cj-exception-tail-outline' -verify-each -S < %s | FileCheck %s
; RUN: opt -passes=cj-exception-tail-outline -enable-cangjie-exception-tail-extract=false -verify-each -S < %s | FileCheck %s --check-prefix=OFF
;
; C03f2 IRBuilder.CreateExceptionAndThrow consumes the constructor's updated
; receiver. Outlining must preserve that value, not throw the stale allocation.
; Allocation type/size and constructor type info remain independent operands.
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
@allocation = external global %TypeInfo
@constructor = external global %TypeInfo
@sink = global i8 addrspace(1)* null
@effect = global i32 0

declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare void @CJ_MCC_ThrowException(i8 addrspace(1)*)
declare i8 addrspace(1)* @ctor(i8 addrspace(1)*, %TypeInfo*)
declare i8 addrspace(1)* @ctor_msg(i8 addrspace(1)*, %"record.std.core:String"*, %TypeInfo*)
declare void @void_ctor(i8 addrspace(1)*, %TypeInfo*)
declare fastcc i8 addrspace(1)* @fast_ctor(i8 addrspace(1)*, %TypeInfo*)
declare noundef i8 addrspace(1)* @attr_ctor(i8 addrspace(1)*, %TypeInfo*)

; CHECK-LABEL: define void @updated_receiver(
; CHECK-NEXT: call void @"__cj$exception_tail_helper0_ref"(i8* bitcast (%TypeInfo* @allocation to i8*), i32 73, i8 addrspace(1)* (i8 addrspace(1)*, %TypeInfo*)* @ctor, %TypeInfo* @constructor)
; CHECK-NEXT: unreachable
; OFF-LABEL: define void @updated_receiver(
; OFF-NEXT: %obj = call i8 addrspace(1)* @CJ_MCC_NewObject
; OFF-NEXT: %updated = call i8 addrspace(1)* @ctor
; OFF-NEXT: call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
define void @updated_receiver() gc "cangjie" {
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @allocation to i8*), i32 73)
  %updated = call i8 addrspace(1)* @ctor(i8 addrspace(1)* %obj, %TypeInfo* @constructor)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
  unreachable
}

; CHECK-LABEL: define void @updated_string(
; CHECK-NEXT: call void @"__cj$exception_tail_helper_string_ref"(i8* bitcast (%TypeInfo* @allocation to i8*), i32 91, i8 addrspace(1)* (i8 addrspace(1)*, %"record.std.core:String"*, %TypeInfo*)* @ctor_msg, %TypeInfo* poison, %"record.std.core:String"* %msg)
; CHECK-NEXT: unreachable
define void @updated_string(%"record.std.core:String"* %msg) gc "cangjie" {
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @allocation to i8*), i32 91)
  %updated = call i8 addrspace(1)* @ctor_msg(i8 addrspace(1)* %obj, %"record.std.core:String"* %msg, %TypeInfo* poison)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
  unreachable
}

; CHECK-LABEL: define void @stale_receiver(
; CHECK: %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @allocation to i8*), i32 73)
; CHECK-NEXT: %updated = call i8 addrspace(1)* @ctor(i8 addrspace(1)* %obj, %TypeInfo* @constructor)
; CHECK-NEXT: call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
; CHECK-NEXT: unreachable
define void @stale_receiver() gc "cangjie" {
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @allocation to i8*), i32 73)
  %updated = call i8 addrspace(1)* @ctor(i8 addrspace(1)* %obj, %TypeInfo* @constructor)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
}

; CHECK-LABEL: define void @extra_updated_use(
; CHECK: %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @allocation to i8*), i32 73)
; CHECK-NEXT: %updated = call i8 addrspace(1)* @ctor(i8 addrspace(1)* %obj, %TypeInfo* @constructor)
; CHECK-NEXT: store volatile i8 addrspace(1)* %updated, i8 addrspace(1)** @sink
; CHECK-NEXT: call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
; CHECK-NEXT: unreachable
define void @extra_updated_use() gc "cangjie" {
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @allocation to i8*), i32 73)
  %updated = call i8 addrspace(1)* @ctor(i8 addrspace(1)* %obj, %TypeInfo* @constructor)
  store volatile i8 addrspace(1)* %updated, i8 addrspace(1)** @sink
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
  unreachable
}

; CHECK-LABEL: define void @extra_allocation_use(
; CHECK: %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @allocation to i8*), i32 73)
; CHECK-NEXT: store volatile i8 addrspace(1)* %obj, i8 addrspace(1)** @sink
; CHECK-NEXT: %updated = call i8 addrspace(1)* @ctor(i8 addrspace(1)* %obj, %TypeInfo* @constructor)
; CHECK-NEXT: call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
; CHECK-NEXT: unreachable
define void @extra_allocation_use() gc "cangjie" {
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @allocation to i8*), i32 73)
  store volatile i8 addrspace(1)* %obj, i8 addrspace(1)** @sink
  %updated = call i8 addrspace(1)* @ctor(i8 addrspace(1)* %obj, %TypeInfo* @constructor)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
  unreachable
}

; CHECK-LABEL: define void @effect_after_ctor(
; CHECK: %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @allocation to i8*), i32 73)
; CHECK-NEXT: %updated = call i8 addrspace(1)* @ctor(i8 addrspace(1)* %obj, %TypeInfo* @constructor)
; CHECK-NEXT: store volatile i32 1, i32* @effect
; CHECK-NEXT: call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
; CHECK-NEXT: unreachable
define void @effect_after_ctor() gc "cangjie" {
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @allocation to i8*), i32 73)
  %updated = call i8 addrspace(1)* @ctor(i8 addrspace(1)* %obj, %TypeInfo* @constructor)
  store volatile i32 1, i32* @effect
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
  unreachable
}

; CHECK-LABEL: define void @effect_before_ctor(
; CHECK: %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @allocation to i8*), i32 73)
; CHECK-NEXT: store volatile i32 1, i32* @effect
; CHECK-NEXT: %updated = call i8 addrspace(1)* @ctor(i8 addrspace(1)* %obj, %TypeInfo* @constructor)
; CHECK-NEXT: call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
; CHECK-NEXT: unreachable
define void @effect_before_ctor() gc "cangjie" {
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @allocation to i8*), i32 73)
  store volatile i32 1, i32* @effect
  %updated = call i8 addrspace(1)* @ctor(i8 addrspace(1)* %obj, %TypeInfo* @constructor)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
  unreachable
}

; CHECK-LABEL: define void @calling_convention(
; CHECK: %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @allocation to i8*), i32 73)
; CHECK-NEXT: %updated = call fastcc i8 addrspace(1)* @fast_ctor(i8 addrspace(1)* %obj, %TypeInfo* @constructor)
; CHECK-NEXT: call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
; CHECK-NEXT: unreachable
define void @calling_convention() gc "cangjie" {
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @allocation to i8*), i32 73)
  %updated = call fastcc i8 addrspace(1)* @fast_ctor(i8 addrspace(1)* %obj, %TypeInfo* @constructor)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
  unreachable
}

; CHECK-LABEL: define void @return_attribute(
; CHECK: %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @allocation to i8*), i32 73)
; CHECK-NEXT: %updated = call noundef i8 addrspace(1)* @attr_ctor(i8 addrspace(1)* %obj, %TypeInfo* @constructor)
; CHECK-NEXT: call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
; CHECK-NEXT: unreachable
define void @return_attribute() gc "cangjie" {
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @allocation to i8*), i32 73)
  %updated = call noundef i8 addrspace(1)* @attr_ctor(i8 addrspace(1)* %obj, %TypeInfo* @constructor)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
  unreachable
}

; CHECK-LABEL: define void @operand_bundle(
; CHECK: %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @allocation to i8*), i32 73)
; CHECK-NEXT: %updated = call i8 addrspace(1)* @ctor(i8 addrspace(1)* %obj, %TypeInfo* @constructor) [ "deopt"(i32 9) ]
; CHECK-NEXT: call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
; CHECK-NEXT: unreachable
define void @operand_bundle() gc "cangjie" {
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @allocation to i8*), i32 73)
  %updated = call i8 addrspace(1)* @ctor(i8 addrspace(1)* %obj, %TypeInfo* @constructor) [ "deopt"(i32 9) ]
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %updated)
  unreachable
}

; Both ABIs occur in one module: neither helper may shadow the other.
; CHECK-LABEL: define void @void_control(
; CHECK-NEXT: call void @"__cj$exception_tail_helper0"(i8* bitcast (%TypeInfo* @allocation to i8*), i32 73, void (i8 addrspace(1)*, %TypeInfo*)* @void_ctor, %TypeInfo* @constructor)
; CHECK-NEXT: unreachable
define void @void_control() gc "cangjie" {
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @allocation to i8*), i32 73)
  call void @void_ctor(i8 addrspace(1)* %obj, %TypeInfo* @constructor)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
}

; The actual helper throw consumes the indirect constructor result. No load of
; constructor metadata, recomputed allocation size or stale receiver is allowed.
; CHECK-LABEL: define internal void @"__cj$exception_tail_helper0_ref"(
; CHECK: %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* %alloc_ti, i32 %alloc_size)
; CHECK-NEXT: [[UPDATED:%.*]] = call i8 addrspace(1)* %ctor(i8 addrspace(1)* %obj, %TypeInfo* %ctor_ti)
; CHECK-NEXT: call void @CJ_MCC_ThrowException(i8 addrspace(1)* [[UPDATED]])
; CHECK-NEXT: unreachable
; CHECK-LABEL: define internal void @"__cj$exception_tail_helper_string_ref"(
; CHECK: %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* %alloc_ti, i32 %alloc_size)
; CHECK-NEXT: [[MSGUPDATED:%.*]] = call i8 addrspace(1)* %ctor(i8 addrspace(1)* %obj, %"record.std.core:String"* %msg, %TypeInfo* %ctor_ti)
; CHECK-NEXT: call void @CJ_MCC_ThrowException(i8 addrspace(1)* [[MSGUPDATED]])
; CHECK-NEXT: unreachable
; OFF-NOT: define internal void @"__cj$exception_tail_helper
