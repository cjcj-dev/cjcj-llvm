; RUN: opt < %s --cangjie-pipeline -passes=inline -S | FileCheck %s --check-prefixes=CJ
; RUN: opt < %s -passes=inline -S | FileCheck %s --check-prefixes=NOCJ

; SetDebugLocation only records a source location for Cangjie stack traces and
; AsmPrinter emits no instruction for it, so under the Cangjie pipeline the
; inline cost model must not charge it as a call. @with_locations is only over
; the threshold when each of its 16 SetDebugLocation calls pays a call penalty.
; @with_real_calls makes 16 real calls and must stay out of line.

declare void @SetDebugLocation()
declare void @opaque(i64)

define i64 @with_locations(i64 %v0) {
entry:
  call void @SetDebugLocation()
  %v1 = add i64 %v0, 1
  call void @SetDebugLocation()
  %v2 = add i64 %v1, 2
  call void @SetDebugLocation()
  %v3 = add i64 %v2, 3
  call void @SetDebugLocation()
  %v4 = add i64 %v3, 4
  call void @SetDebugLocation()
  %v5 = add i64 %v4, 5
  call void @SetDebugLocation()
  %v6 = add i64 %v5, 6
  call void @SetDebugLocation()
  %v7 = add i64 %v6, 7
  call void @SetDebugLocation()
  %v8 = add i64 %v7, 8
  call void @SetDebugLocation()
  %v9 = add i64 %v8, 9
  call void @SetDebugLocation()
  %v10 = add i64 %v9, 10
  call void @SetDebugLocation()
  %v11 = add i64 %v10, 11
  call void @SetDebugLocation()
  %v12 = add i64 %v11, 12
  call void @SetDebugLocation()
  %v13 = add i64 %v12, 13
  call void @SetDebugLocation()
  %v14 = add i64 %v13, 14
  call void @SetDebugLocation()
  %v15 = add i64 %v14, 15
  call void @SetDebugLocation()
  %v16 = add i64 %v15, 16
  call void @opaque(i64 %v16)
  ret i64 %v16
}

define void @with_real_calls() {
entry:
  call void @opaque(i64 1)
  call void @opaque(i64 2)
  call void @opaque(i64 3)
  call void @opaque(i64 4)
  call void @opaque(i64 5)
  call void @opaque(i64 6)
  call void @opaque(i64 7)
  call void @opaque(i64 8)
  call void @opaque(i64 9)
  call void @opaque(i64 10)
  call void @opaque(i64 11)
  call void @opaque(i64 12)
  call void @opaque(i64 13)
  call void @opaque(i64 14)
  call void @opaque(i64 15)
  call void @opaque(i64 16)
  ret void
}

define i64 @caller(i64 %x) {
; CJ-LABEL: define i64 @caller(
; CJ-NOT: call i64 @with_locations(
; CJ: call void @opaque(
; CJ: call void @with_real_calls()
; CJ: ret i64
; NOCJ-LABEL: define i64 @caller(
; NOCJ: call i64 @with_locations(
; NOCJ: call void @with_real_calls()
  %r = call i64 @with_locations(i64 %x)
  call void @with_real_calls()
  ret i64 %r
}
