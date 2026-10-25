; RUN: opt -passes=cj-exception-tail-outline -verify-each -S < %s | FileCheck %s
; RUN: opt -passes=cj-exception-tail-outline -enable-cangjie-exception-tail-extract=false -S < %s | FileCheck %s --check-prefix=DISABLED
;
; A cangjie throw site is the cold tail
;   %obj = call @CJ_MCC_NewObject(..., size)
;   call @exception_ctor(%obj, [msg,] ti)
;   call @CJ_MCC_ThrowException(%obj)
;   unreachable
; and the pass replaces it with a call of one helper shared by every site that
; uses the same constructor signature. The helper preserves the independent
; allocation TypeInfo, allocation size and constructor TypeInfo operands.

%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }

@TI = external global %TypeInfo

declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare void @CJ_MCC_ThrowException(i8 addrspace(1)*)
declare void @_CExCtor(i8 addrspace(1)*, %TypeInfo*)
declare void @_CExCtorMsg(i8 addrspace(1)*, %"record.std.core:String"*, %TypeInfo*)

; CHECK-LABEL: define void @ctor0(
; CHECK:         call void @"__cj$exception_tail_helper0"(i8* bitcast (%TypeInfo* @TI to i8*), i32 32, void (i8 addrspace(1)*, %TypeInfo*)* @_CExCtor, %TypeInfo* @TI) #[[CALL:[0-9]+]]
; CHECK-NEXT:    unreachable
define void @ctor0(i1 %c) gc "cangjie" {
entry:
  br i1 %c, label %t, label %r
t:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @TI to i8*), i32 32)
  call void @_CExCtor(i8 addrspace(1)* %obj, %TypeInfo* @TI)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
r:
  ret void
}

; A different size constant still lands on the same helper.
; CHECK-LABEL: define void @ctor0b(
; CHECK:         call void @"__cj$exception_tail_helper0"(i8* bitcast (%TypeInfo* @TI to i8*), i32 64, void (i8 addrspace(1)*, %TypeInfo*)* @_CExCtor, %TypeInfo* @TI)
define void @ctor0b(i1 %c) gc "cangjie" {
entry:
  br i1 %c, label %t, label %r
t:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @TI to i8*), i32 64)
  call void @_CExCtor(i8 addrspace(1)* %obj, %TypeInfo* @TI)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
r:
  ret void
}

; DeadArgumentElimination rewrites the trailing TypeInfo operand of a
; constructor it can prove unused to poison. Keep that operand poison while
; passing the original allocation TypeInfo and size separately to the helper.
; CHECK-LABEL: define void @poisonTi(
; CHECK:         call void @"__cj$exception_tail_helper0"(i8* bitcast (%TypeInfo* @TI to i8*), i32 64, void (i8 addrspace(1)*, %TypeInfo*)* @_CExCtor, %TypeInfo* poison) #[[CALL]]
; CHECK-NEXT:    unreachable
define void @poisonTi(i1 %c) gc "cangjie" {
entry:
  br i1 %c, label %t, label %r
t:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @TI to i8*), i32 64)
  call void @_CExCtor(i8 addrspace(1)* %obj, %TypeInfo* poison)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
r:
  ret void
}

; The message is a real operand, only the type info was replaced.
; CHECK-LABEL: define void @poisonTiStr(
; CHECK:         %msg = load
; CHECK-NEXT:    call void @"__cj$exception_tail_helper_string"(i8* bitcast (%TypeInfo* @TI to i8*), i32 64, void (i8 addrspace(1)*, %"record.std.core:String"*, %TypeInfo*)* @_CExCtorMsg, %TypeInfo* poison, %"record.std.core:String"* %msg) #[[CALL]]
; CHECK-NEXT:    unreachable
define void @poisonTiStr(i1 %c, %"record.std.core:String"** %msgp) gc "cangjie" {
entry:
  br i1 %c, label %t, label %r
t:
  %msg = load %"record.std.core:String"*, %"record.std.core:String"** %msgp
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @TI to i8*), i32 64)
  call void @_CExCtorMsg(i8 addrspace(1)* %obj, %"record.std.core:String"* %msg, %TypeInfo* poison)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
r:
  ret void
}

; The message stays an operand of the call site, only the throw itself moves.
; CHECK-LABEL: define void @ctorStr(
; CHECK:         %msg = load
; CHECK-NEXT:    call void @"__cj$exception_tail_helper_string"(i8* bitcast (%TypeInfo* @TI to i8*), i32 48, void (i8 addrspace(1)*, %"record.std.core:String"*, %TypeInfo*)* @_CExCtorMsg, %TypeInfo* @TI, %"record.std.core:String"* %msg) #[[CALL]]
; CHECK-NEXT:    unreachable
define void @ctorStr(i1 %c, %"record.std.core:String"** %msgp) gc "cangjie" {
entry:
  br i1 %c, label %t, label %r
t:
  %msg = load %"record.std.core:String"*, %"record.std.core:String"** %msgp
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @TI to i8*), i32 48)
  call void @_CExCtorMsg(i8 addrspace(1)* %obj, %"record.std.core:String"* %msg, %TypeInfo* @TI)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
r:
  ret void
}

; CHECK:       define internal void @"__cj$exception_tail_helper0"(i8* %alloc_ti, i32 %alloc_size, void (i8 addrspace(1)*, %TypeInfo*)* %ctor, %TypeInfo* %ctor_ti) #[[HELPER:[0-9]+]] gc "cangjie"
; CHECK-NEXT:  entry:
; CHECK-NEXT:    %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* %alloc_ti, i32 %alloc_size)
; CHECK-NEXT:    call void %ctor(i8 addrspace(1)* %obj, %TypeInfo* %ctor_ti)
; CHECK-NEXT:    call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
; CHECK-NEXT:    unreachable
; CHECK:       define internal void @"__cj$exception_tail_helper_string"(i8* %alloc_ti, i32 %alloc_size, void (i8 addrspace(1)*, %"record.std.core:String"*, %TypeInfo*)* %ctor, %TypeInfo* %ctor_ti, %"record.std.core:String"* %msg)
; CHECK-NEXT:  entry:
; CHECK-NEXT:    %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* %alloc_ti, i32 %alloc_size)
; CHECK-NEXT:    call void %ctor(i8 addrspace(1)* %obj, %"record.std.core:String"* %msg, %TypeInfo* %ctor_ti)
; CHECK-NEXT:    call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
; CHECK-NEXT:    unreachable
; CHECK:       attributes #[[HELPER]] = { cold minsize noinline noreturn optsize }
; CHECK:       attributes #[[CALL]] = { noreturn }

; The flag turns the pass off and leaves the module untouched.
; DISABLED-LABEL: define void @ctor0(
; DISABLED:         %obj = call i8 addrspace(1)* @CJ_MCC_NewObject
; DISABLED-NEXT:    call void @_CExCtor(i8 addrspace(1)* %obj, %TypeInfo* @TI)
; DISABLED-NEXT:    call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
; DISABLED-NEXT:    unreachable
; DISABLED-NOT:     @"__cj$exception_tail_helper
