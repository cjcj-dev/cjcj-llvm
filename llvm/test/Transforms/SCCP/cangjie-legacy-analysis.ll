; RUN: opt -enable-new-pm=0 -sccp --cangjie-pipeline -S < %s | FileCheck %s
; RUN: opt -passes=sccp --cangjie-pipeline -S < %s | FileCheck %s
; RUN: opt -enable-new-pm=0 -O2 --cangjie-pipeline -S < %s | FileCheck %s

; The legacy SCCP entry must declare the LoopInfo it consumes in the
; Cangjie pipeline. Check both its ordinary constant result and a live loop
; whose header phi requires the loop analysis in the shared solver.

; CHECK-LABEL: define i32 @fold_constant(
; CHECK: ret i32 42
define i32 @fold_constant() {
entry:
  %sum = add i32 20, 22
  ret i32 %sum
}

declare void @observe(i32)

; CHECK-LABEL: define void @live_loop(
; CHECK: call void @observe(i32
; CHECK: br i1 %done
; CHECK: ret void
define void @live_loop(i1 %done) {
entry:
  br label %header
header:
  %value = phi i32 [ 1, %entry ], [ 2, %latch ]
  call void @observe(i32 %value)
  br i1 %done, label %exit, label %latch
latch:
  br label %header
exit:
  ret void
}
