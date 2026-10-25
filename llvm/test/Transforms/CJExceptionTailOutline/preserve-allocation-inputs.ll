; RUN: opt -passes=cj-exception-tail-outline -verify-each -S < %s | FileCheck %s
; RUN: opt -passes=cj-exception-tail-outline -enable-cangjie-exception-tail-extract=false -verify-each -S < %s | FileCheck %s --check-prefix=DISABLED
;
; Allocation metadata/size and constructor metadata are independent operands.
; Do not infer one from the other or add a metadata dereference. Both canonical
; ctor forms still outline; unsupported address spaces keep the original tail.

%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
@TI = external global %TypeInfo
@OtherTI = external global %TypeInfo

declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare void @CJ_MCC_ThrowException(i8 addrspace(1)*)
declare void @ctor(i8 addrspace(1)*, %TypeInfo*)
declare void @string_ctor(i8 addrspace(1)*, %"record.std.core:String"*, %TypeInfo*)
declare void @as1_ctor(i8 addrspace(1)*, %TypeInfo addrspace(1)*)
declare void @_CNat6Ctor0(i8 addrspace(1)*, %TypeInfo*)

; CHECK-LABEL: define void @null_ctor(
; CHECK-NEXT: entry:
; CHECK-NEXT: call void @"__cj$exception_tail_helper0"(i8* bitcast (%TypeInfo* @TI to i8*), i32 32, void (i8 addrspace(1)*, %TypeInfo*)* @ctor, %TypeInfo* null)
; CHECK-NEXT: unreachable
define void @null_ctor(i32 %size) gc "cangjie" {
entry:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @TI to i8*), i32 32)
  call void @ctor(i8 addrspace(1)* %obj, %TypeInfo* null)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
}

; CHECK-LABEL: define void @distinct_ctor(
; CHECK-NEXT: entry:
; CHECK-NEXT: call void @"__cj$exception_tail_helper0"(i8* bitcast (%TypeInfo* @TI to i8*), i32 %size, void (i8 addrspace(1)*, %TypeInfo*)* @ctor, %TypeInfo* @OtherTI)
; CHECK-NEXT: unreachable
define void @distinct_ctor(i32 %size) gc "cangjie" {
entry:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @TI to i8*), i32 %size)
  call void @ctor(i8 addrspace(1)* %obj, %TypeInfo* @OtherTI)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
}

; CHECK-LABEL: define void @undef_ctor(
; CHECK-NEXT: entry:
; CHECK-NEXT: call void @"__cj$exception_tail_helper0"(i8* bitcast (%TypeInfo* @TI to i8*), i32 %size, void (i8 addrspace(1)*, %TypeInfo*)* @ctor, %TypeInfo* undef)
; CHECK-NEXT: unreachable
define void @undef_ctor(i32 %size) gc "cangjie" {
entry:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @TI to i8*), i32 %size)
  call void @ctor(i8 addrspace(1)* %obj, %TypeInfo* undef)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
}

; CHECK-LABEL: define void @null_string(
; CHECK-NEXT: entry:
; CHECK-NEXT: call void @"__cj$exception_tail_helper_string"(i8* bitcast (%TypeInfo* @TI to i8*), i32 %size, void (i8 addrspace(1)*, %"record.std.core:String"*, %TypeInfo*)* @string_ctor, %TypeInfo* null, %"record.std.core:String"* %msg)
; CHECK-NEXT: unreachable
define void @null_string(i32 %size, %"record.std.core:String"* %msg) gc "cangjie" {
entry:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @TI to i8*), i32 %size)
  call void @string_ctor(i8 addrspace(1)* %obj, %"record.std.core:String"* %msg, %TypeInfo* null)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
}

; CHECK-LABEL: define void @distinct_string(
; CHECK-NEXT: entry:
; CHECK-NEXT: call void @"__cj$exception_tail_helper_string"(i8* bitcast (%TypeInfo* @TI to i8*), i32 64, void (i8 addrspace(1)*, %"record.std.core:String"*, %TypeInfo*)* @string_ctor, %TypeInfo* @OtherTI, %"record.std.core:String"* %msg)
; CHECK-NEXT: unreachable
define void @distinct_string(i32 %size, %"record.std.core:String"* %msg) gc "cangjie" {
entry:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @TI to i8*), i32 64)
  call void @string_ctor(i8 addrspace(1)* %obj, %"record.std.core:String"* %msg, %TypeInfo* @OtherTI)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
}

; CHECK-LABEL: define void @unsupported_as1(
; CHECK-NEXT: entry:
; CHECK-NEXT: %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* %alloc_ti, i32 %size)
; CHECK-NEXT: call void @as1_ctor(i8 addrspace(1)* %obj, %TypeInfo addrspace(1)* %ctor_ti)
; CHECK-NEXT: call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
; CHECK-NEXT: unreachable
define void @unsupported_as1(i8* %alloc_ti, i32 %size, %TypeInfo addrspace(1)* %ctor_ti) gc "cangjie" {
entry:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* %alloc_ti, i32 %size)
  call void @as1_ctor(i8 addrspace(1)* %obj, %TypeInfo addrspace(1)* %ctor_ti)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
}

; Preserve poison independently on both calls; the helper adds no dereference.
; CHECK-LABEL: define void @poison_ti(
; CHECK:         call void @"__cj$exception_tail_helper0"(i8* poison, i32 32, void (i8 addrspace(1)*, %TypeInfo*)* @_CNat6Ctor0, %TypeInfo* poison)
; CHECK-NEXT:    unreachable
define void @poison_ti(i1 %c) gc "cangjie" {
entry:
  br i1 %c, label %t, label %r
t:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* poison, i32 32)
  call void @_CNat6Ctor0(i8 addrspace(1)* %obj, %TypeInfo* poison)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
r:
  ret void
}

; An opaque allocation pointer is forwarded unchanged, not interpreted as the
; constructor TypeInfo. This case was formerly skipped by ResolveTypeInfo.
; CHECK-LABEL: define void @poison_ti_raw_alloc(
; CHECK:         call void @"__cj$exception_tail_helper0"(i8* %raw, i32 32, void (i8 addrspace(1)*, %TypeInfo*)* @_CNat6Ctor0, %TypeInfo* poison)
; CHECK-NEXT:    unreachable
define void @poison_ti_raw_alloc(i1 %c, i8* %raw) gc "cangjie" {
entry:
  br i1 %c, label %t, label %r
t:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* %raw, i32 32)
  call void @_CNat6Ctor0(i8 addrspace(1)* %obj, %TypeInfo* poison)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  unreachable
r:
  ret void
}

; CHECK-LABEL: define internal void @"__cj$exception_tail_helper0"(
; CHECK-NEXT: entry:
; CHECK-NEXT: %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* %alloc_ti, i32 %alloc_size)
; CHECK-NEXT: call void %ctor(i8 addrspace(1)* %obj, %TypeInfo* %ctor_ti)
; CHECK-NEXT: call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
; CHECK-NEXT: unreachable

; CHECK-LABEL: define internal void @"__cj$exception_tail_helper_string"(
; CHECK-NEXT: entry:
; CHECK-NEXT: %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* %alloc_ti, i32 %alloc_size)
; CHECK-NEXT: call void %ctor(i8 addrspace(1)* %obj, %"record.std.core:String"* %msg, %TypeInfo* %ctor_ti)
; CHECK-NEXT: call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
; CHECK-NEXT: unreachable

; DISABLED-LABEL: define void @null_ctor(
; DISABLED-NEXT: entry:
; DISABLED-NEXT: %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @TI to i8*), i32 32)
; DISABLED-NEXT: call void @ctor(i8 addrspace(1)* %obj, %TypeInfo* null)
; DISABLED-NEXT: call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
; DISABLED-NEXT: unreachable
; DISABLED-NOT: @"__cj$exception_tail_helper
