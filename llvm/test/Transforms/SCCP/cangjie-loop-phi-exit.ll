; RUN: opt -passes=sccp --cangjie-pipeline -S < %s | FileCheck %s

; A loop-header phi [true, preheader], [false, latch] is not the latch
; constant on the header exit. The first iteration still carries true.
define i1 @exit_keeps_preheader(i1 %done) {
; CHECK-LABEL: @exit_keeps_preheader(
; CHECK-NOT: ret i1 false
; CHECK: ret i1 %out
entry:
  br label %header

header:
  %s = phi i1 [ true, %entry ], [ false, %latch ]
  br i1 %done, label %exit, label %latch

latch:
  br label %header

exit:
  %out = phi i1 [ %s, %header ]
  ret i1 %out
}
