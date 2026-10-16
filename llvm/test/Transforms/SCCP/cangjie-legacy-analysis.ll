; RUN: opt -enable-new-pm=0 -sccp --cangjie-pipeline -S < %s | FileCheck %s
; RUN: opt -passes=sccp --cangjie-pipeline -S < %s | FileCheck %s
; RUN: opt -enable-new-pm=0 -O2 --cangjie-pipeline -S < %s | FileCheck %s
; RUN: opt -enable-new-pm=0 -sccp -S < %s | FileCheck %s
; RUN: opt -passes=sccp -S < %s | FileCheck %s
; RUN: opt -passes='require<domtree>,sccp,verify<domtree>' -S < %s | FileCheck %s
; RUN: opt -enable-new-pm=0 -domtree -sccp -verify-dom-info -S < %s | FileCheck %s
; RUN: opt -passes=sccp -debug-pass-manager -disable-output < %s 2>&1 | FileCheck %s --check-prefix=OPTIONAL

; OPTIONAL-NOT: Running analysis: DominatorTreeAnalysis
; OPTIONAL: Running pass: SCCPPass on fold_constant
; OPTIONAL-NOT: Running analysis: DominatorTreeAnalysis
; OPTIONAL: Running pass: SCCPPass on live_loop
; OPTIONAL-NOT: Running analysis: DominatorTreeAnalysis

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
