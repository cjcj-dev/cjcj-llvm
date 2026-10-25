; RUN: opt -passes=cj-exception-tail-outline -verify-each -S < %s | FileCheck %s
;
; An ordinary C call can still have a type incompatible with the constructor
; pointer accepted by the helper. Keep both non-void shapes intact; supported
; void constructors in the same module remain eligible for outlining.
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
@TI = external global %TypeInfo

declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare void @CJ_MCC_ThrowException(i8 addrspace(1)*)
declare i32 @nonvoid_ctor(i8 addrspace(1)*, %TypeInfo*)
declare i32 @nonvoid_string_ctor(i8 addrspace(1)*, %"record.std.core:String"*, %TypeInfo*)
declare void @void_ctor(i8 addrspace(1)*, %TypeInfo*)
declare void @void_string_ctor(i8 addrspace(1)*, %"record.std.core:String"*, %TypeInfo*)

; CHECK-LABEL: define void @keep_nonvoid_ctor(
; CHECK: %obj = call i8 addrspace(1)* @CJ_MCC_NewObject
; CHECK-NEXT: %unused = call i32 @nonvoid_ctor
; CHECK-NEXT: call void @CJ_MCC_ThrowException
; CHECK-NEXT: unreachable
define void @keep_nonvoid_ctor() gc "cangjie" {
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @TI to i8*), i32 32)
  %unused = call i32 @nonvoid_ctor(i8 addrspace(1)* %obj, %TypeInfo* @TI)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
}

; CHECK-LABEL: define void @keep_nonvoid_string_ctor(
; CHECK: %obj = call i8 addrspace(1)* @CJ_MCC_NewObject
; CHECK-NEXT: %unused = call i32 @nonvoid_string_ctor
; CHECK-NEXT: call void @CJ_MCC_ThrowException
; CHECK-NEXT: unreachable
define void @keep_nonvoid_string_ctor(%"record.std.core:String"* %msg) gc "cangjie" {
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @TI to i8*), i32 32)
  %unused = call i32 @nonvoid_string_ctor(i8 addrspace(1)* %obj, %"record.std.core:String"* %msg, %TypeInfo* @TI)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
}

; CHECK-LABEL: define void @void_ctor_control(
; CHECK-NEXT: call void @"__cj$exception_tail_helper0"
; CHECK-NEXT: unreachable
define void @void_ctor_control() gc "cangjie" {
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @TI to i8*), i32 32)
  call void @void_ctor(i8 addrspace(1)* %obj, %TypeInfo* @TI)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
}

; CHECK-LABEL: define void @void_string_ctor_control(
; CHECK-NEXT: call void @"__cj$exception_tail_helper_string"
; CHECK-NEXT: unreachable
define void @void_string_ctor_control(%"record.std.core:String"* %msg) gc "cangjie" {
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @TI to i8*), i32 32)
  call void @void_string_ctor(i8 addrspace(1)* %obj, %"record.std.core:String"* %msg, %TypeInfo* @TI)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
}
