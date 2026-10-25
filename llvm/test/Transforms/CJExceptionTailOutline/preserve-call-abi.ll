; RUN: opt -passes=cj-exception-tail-outline -S < %s | FileCheck %s
;
; GlobalOpt can produce fastcc calls on the normal pipeline. The C-ABI
; helpers cannot replace these calls solely because FunctionType matches.
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
@TI = external global %TypeInfo

declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare void @CJ_MCC_ThrowException(i8 addrspace(1)*)
declare fastcc void @fast_ctor(i8 addrspace(1)*, %TypeInfo*)
declare void @plain_ctor(i8 addrspace(1)*, %TypeInfo*)
declare fastcc i8 addrspace(1)* @"rt$CreateFastException_msg"(%"record.std.core:String"*)
declare i8 addrspace(1)* @"rt$CreateValueException_msg"(%"record.std.core:String"* byval(%"record.std.core:String"))

; CHECK-LABEL: define void @fast_constructor(
; CHECK: %obj = call i8 addrspace(1)* @CJ_MCC_NewObject
; CHECK-NEXT: call fastcc void @fast_ctor
; CHECK-NEXT: call void @CJ_MCC_ThrowException
define void @fast_constructor() gc "cangjie" {
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @TI to i8*), i32 32)
  call fastcc void @fast_ctor(i8 addrspace(1)* %obj, %TypeInfo* @TI)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
}

; CHECK-LABEL: define void @fast_factory(
; CHECK: %obj = call fastcc i8 addrspace(1)* @"rt$CreateFastException_msg"
; CHECK-NEXT: call void @CJ_MCC_ThrowException
define void @fast_factory(%"record.std.core:String"* %msg) gc "cangjie" {
  %obj = call fastcc i8 addrspace(1)* @"rt$CreateFastException_msg"(%"record.std.core:String"* %msg)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
}

; CHECK-LABEL: define void @byval_factory(
; CHECK: %obj = call i8 addrspace(1)* @"rt$CreateValueException_msg"(%"record.std.core:String"* byval(%"record.std.core:String") %msg)
; CHECK-NEXT: call void @CJ_MCC_ThrowException
define void @byval_factory(%"record.std.core:String"* %msg) gc "cangjie" {
  %obj = call i8 addrspace(1)* @"rt$CreateValueException_msg"(%"record.std.core:String"* byval(%"record.std.core:String") %msg)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
}

; The supported C ABI is still outlined in this same module.
; CHECK-LABEL: define void @ordinary_control(
; CHECK-NEXT: call void @"__cj$exception_tail_helper0"
; CHECK-NEXT: unreachable
define void @ordinary_control() gc "cangjie" {
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @TI to i8*), i32 32)
  call void @plain_ctor(i8 addrspace(1)* %obj, %TypeInfo* @TI)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
}
