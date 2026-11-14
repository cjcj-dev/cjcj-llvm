; RUN: rm -rf %t && split-file %s %t
; RUN: opt < %t/callee-attr.ll --cangjie-pipeline -passes=inline -S | FileCheck %t/callee-attr.ll
; RUN: opt < %t/callee-attr.ll -passes=inline -S | FileCheck %t/callee-attr.ll
; RUN: opt < %t/site-attr.ll --cangjie-pipeline -passes=inline -S | FileCheck %t/site-attr.ll --check-prefixes=CHECK,CJ
; RUN: opt < %t/site-attr.ll -passes=inline -S | FileCheck %t/site-attr.ll --check-prefixes=CHECK,NOCJ

; Under the Cangjie pipeline SetDebugLocation is charged nothing, but it is
; still an ordinary IR call: noduplicate and returns_twice on it keep deciding
; whether the callee may be inlined at all, in ordinary blocks and in the
; unreachable-terminated exception blocks that the Cangjie cost walk visits.
; @cold_locs checks that SetDebugLocation stays free in such a block.

;--- callee-attr.ll
declare void @SetDebugLocation() noduplicate nounwind
declare void @ThrowIndexOutOfBoundsException()

define internal void @wrapper() {
entry:
  call void @SetDebugLocation()
  ret void
}

define internal void @cold_wrapper(i1 %c) {
entry:
  br i1 %c, label %throw, label %ok
throw:
  call void @SetDebugLocation()
  call void @ThrowIndexOutOfBoundsException()
  unreachable
ok:
  ret void
}

; Inlining either wrapper at two call sites would duplicate a noduplicate call.
define void @caller(i1 %a, i1 %b) {
; CHECK-LABEL: define void @caller(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    call void @wrapper()
; CHECK-NEXT:    call void @wrapper()
; CHECK-NEXT:    call void @cold_wrapper(i1 %a)
; CHECK-NEXT:    call void @cold_wrapper(i1 %b)
; CHECK-NEXT:    ret void
entry:
  call void @wrapper()
  call void @wrapper()
  call void @cold_wrapper(i1 %a)
  call void @cold_wrapper(i1 %b)
  ret void
}

;--- site-attr.ll
declare void @SetDebugLocation()
declare void @ThrowIndexOutOfBoundsException()

; returns_twice on the call site: inlining would expose it to a caller that is
; not returns_twice.
define internal void @rt_wrapper() {
entry:
  call void @SetDebugLocation() #0
  ret void
}

define void @rt_caller() {
; CHECK-LABEL: define void @rt_caller(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    call void @rt_wrapper()
; CHECK-NEXT:    call void @rt_wrapper()
; CHECK-NEXT:    ret void
entry:
  call void @rt_wrapper()
  call void @rt_wrapper()
  ret void
}

; Only over the threshold when the SetDebugLocation calls on the exception
; path are charged.
define void @cold_locs(i1 %c) {
entry:
  br i1 %c, label %throw, label %ok
throw:
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @SetDebugLocation()
  call void @ThrowIndexOutOfBoundsException()
  unreachable
ok:
  ret void
}

define void @cold_caller(i1 %c) {
; CJ-LABEL: define void @cold_caller(
; CJ-NOT:     call void @cold_locs(
; CJ:         ret void
; NOCJ-LABEL: define void @cold_caller(
; NOCJ-NEXT:  entry:
; NOCJ-NEXT:    call void @cold_locs(i1 %c)
; NOCJ-NEXT:    ret void
entry:
  call void @cold_locs(i1 %c)
  ret void
}

attributes #0 = { returns_twice }
