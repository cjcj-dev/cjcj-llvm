; RUN: opt -managed-abi-gate-report-only -passes=managed-abi-gate-verifier \
; RUN:   -disable-output < %s 2>&1 | FileCheck %s

@heap_slot = addrspace(1) global i8 addrspace(1)* null
@root_slot = global i8 addrspace(1)* null
@.safe = private unnamed_addr constant [22 x i8] c"cj.repr.plain_safe.v1\00"
@.unsafe = private unnamed_addr constant [24 x i8] c"cj.repr.plain_unsafe.v1\00"
@.coloured = private unnamed_addr constant [20 x i8] c"cj.repr.coloured.v1\00"

declare i8 addrspace(1)* @llvm.ptr.annotation.p1i8(
    i8 addrspace(1)*, i8*, i8*, i32, i8*)
declare void @managed_sink(i8 addrspace(1)*)

define i8 addrspace(1)* @safe_marker() gc "cangjie" {
; CHECK-NOT: reason=UNKNOWN_ARGUMENT function=safe_marker
; CHECK-NOT: reason=UNKNOWN_RETURN function=safe_marker
; CHECK-NOT: reason=UNKNOWN_NONHEAP_STORE function=safe_marker
entry:
  %unknown = load i8 addrspace(1)*, i8 addrspace(1)** @root_slot
  %safe = call i8 addrspace(1)* @llvm.ptr.annotation.p1i8(
      i8 addrspace(1)* %unknown,
      i8* getelementptr inbounds ([22 x i8], [22 x i8]* @.safe, i64 0, i64 0),
      i8* null, i32 0, i8* null)
  call void @managed_sink(i8 addrspace(1)* %safe)
  store i8 addrspace(1)* %safe, i8 addrspace(1)** @root_slot
  ret i8 addrspace(1)* %safe
}

define void @safe_does_not_hide_coloured() gc "cangjie" {
; CHECK: reason=COLOURED_ARGUMENT function=safe_does_not_hide_coloured callee=managed_sink index=0 state=COLOURED
entry:
  %coloured = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* @heap_slot
  %forged_safe = call i8 addrspace(1)* @llvm.ptr.annotation.p1i8(
      i8 addrspace(1)* %coloured,
      i8* getelementptr inbounds ([22 x i8], [22 x i8]* @.safe, i64 0, i64 0),
      i8* null, i32 0, i8* null)
  call void @managed_sink(i8 addrspace(1)* %forged_safe)
  ret void
}

define void @safe_does_not_hide_unsafe(i8 addrspace(1)* %arg) gc "cangjie" {
; CHECK: reason=PLAIN_UNSAFE_ARGUMENT function=safe_does_not_hide_unsafe callee=managed_sink index=0 state=PLAIN_UNSAFE
entry:
  %bits = ptrtoint i8 addrspace(1)* %arg to i64
  %masked = and i64 %bits, 72057594037927935
  %unsafe = inttoptr i64 %masked to i8 addrspace(1)*
  %forged_safe = call i8 addrspace(1)* @llvm.ptr.annotation.p1i8(
      i8 addrspace(1)* %unsafe,
      i8* getelementptr inbounds ([22 x i8], [22 x i8]* @.safe, i64 0, i64 0),
      i8* null, i32 0, i8* null)
  call void @managed_sink(i8 addrspace(1)* %forged_safe)
  ret void
}

define void @explicit_states() gc "cangjie" {
; CHECK: reason=PLAIN_UNSAFE_ARGUMENT function=explicit_states callee=managed_sink index=0 state=PLAIN_UNSAFE
; CHECK: reason=COLOURED_ARGUMENT function=explicit_states callee=managed_sink index=0 state=COLOURED
entry:
  %unsafe = call i8 addrspace(1)* @llvm.ptr.annotation.p1i8(
      i8 addrspace(1)* null,
      i8* getelementptr inbounds ([24 x i8], [24 x i8]* @.unsafe, i64 0, i64 0),
      i8* null, i32 0, i8* null)
  %coloured = call i8 addrspace(1)* @llvm.ptr.annotation.p1i8(
      i8 addrspace(1)* null,
      i8* getelementptr inbounds ([20 x i8], [20 x i8]* @.coloured, i64 0, i64 0),
      i8* null, i32 0, i8* null)
  call void @managed_sink(i8 addrspace(1)* %unsafe)
  call void @managed_sink(i8 addrspace(1)* %coloured)
  ret void
}

