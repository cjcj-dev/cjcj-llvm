; RUN: llc --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu < %s | FileCheck %s --check-prefix=ARM
; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu < %s | FileCheck %s --check-prefix=X86
; REQUIRES: aarch64-registered-target, x86-registered-target
; A legacy spelling is no longer a backend intrinsic: preserve an ordinary call.
; ARM-LABEL: ordinary_call:
; ARM: bl GetGCPhase
; X86-LABEL: ordinary_call:
; X86: callq GetGCPhase

define i32 @ordinary_call() {
  %phase = call i32 @GetGCPhase()
  %result = add i32 %phase, 1
  ret i32 %result
}
declare i32 @GetGCPhase()
