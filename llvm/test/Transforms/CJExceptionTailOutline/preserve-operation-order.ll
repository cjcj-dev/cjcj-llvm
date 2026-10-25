; RUN: opt -passes=cj-exception-tail-outline -S < %s | FileCheck %s
;
; A factory or constructor may read message memory and may throw. Outlining
; must not move either call across an intervening operation. The adjacent
; factory below is an independent positive control: this is not a disabled pass.
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
@TI = external global %TypeInfo
@state = global i32 0

declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare void @CJ_MCC_ThrowException(i8 addrspace(1)*)
declare void @_CExCtor(i8 addrspace(1)*, %TypeInfo*)
declare i8 addrspace(1)* @"rt$CreateOverflowException_msg"(%"record.std.core:String"*)

; CHECK-LABEL: define void @factory_store(
; CHECK: %obj = call i8 addrspace(1)* @"rt$CreateOverflowException_msg"
; CHECK-NEXT: store i32 9, i32* %field
; CHECK-NEXT: call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
define void @factory_store(%"record.std.core:String"* %msg, i32* %field) gc "cangjie" {
  %obj = call i8 addrspace(1)* @"rt$CreateOverflowException_msg"(%"record.std.core:String"* %msg)
  store i32 9, i32* %field
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
}

; CHECK-LABEL: define void @allocation_volatile_store(
; CHECK: %obj = call i8 addrspace(1)* @CJ_MCC_NewObject
; CHECK-NEXT: store volatile i32 1, i32* @state
; CHECK-NEXT: call void @_CExCtor
; CHECK-NEXT: call void @CJ_MCC_ThrowException
define void @allocation_volatile_store() gc "cangjie" {
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @TI to i8*), i32 32)
  store volatile i32 1, i32* @state
  call void @_CExCtor(i8 addrspace(1)* %obj, %TypeInfo* @TI)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
}

; CHECK-LABEL: define void @constructor_atomic_store(
; CHECK: %obj = call i8 addrspace(1)* @CJ_MCC_NewObject
; CHECK-NEXT: call void @_CExCtor
; CHECK-NEXT: store atomic i32 2, i32* @state release, align 4
; CHECK-NEXT: call void @CJ_MCC_ThrowException
define void @constructor_atomic_store() gc "cangjie" {
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @TI to i8*), i32 32)
  call void @_CExCtor(i8 addrspace(1)* %obj, %TypeInfo* @TI)
  store atomic i32 2, i32* @state release, align 4
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
}

; A load may trap, and can observe a constructor's writes. It stays after it.
; CHECK-LABEL: define void @constructor_load(
; CHECK: call void @_CExCtor
; CHECK-NEXT: %value = load volatile i32, i32* %p
; CHECK-NEXT: call void @CJ_MCC_ThrowException
define void @constructor_load(i32* %p) gc "cangjie" {
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @TI to i8*), i32 32)
  call void @_CExCtor(i8 addrspace(1)* %obj, %TypeInfo* @TI)
  %value = load volatile i32, i32* %p
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
}

; CHECK-LABEL: define void @adjacent_control(
; CHECK-NEXT: call void @"__cj$exception_tail_helper_factory"
; CHECK-NEXT: unreachable
define void @adjacent_control(%"record.std.core:String"* %msg) gc "cangjie" {
  %obj = call i8 addrspace(1)* @"rt$CreateOverflowException_msg"(%"record.std.core:String"* %msg)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
}
