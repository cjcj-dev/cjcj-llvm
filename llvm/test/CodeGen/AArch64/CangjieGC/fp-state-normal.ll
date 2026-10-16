; RUN: llc --cangjie-pipeline -opaque-pointers=0 -O2 -mtriple=aarch64-unknown-linux-gnu %s -o - | FileCheck %s
; REQUIRES: aarch64-registered-target
;
; Independent control for the extra-operand failure: ordinary MRS still has
; its normal two operands, and integer selection does not use the FP hook.
; CHECK-LABEL: ordinary_fp_state:
; CHECK: mrs x0, FPSR
; CHECK-NEXT: ret
define i64 @ordinary_fp_state() {
  %state = call i64 @llvm.aarch64.get.fpsr()
  ret i64 %state
}

; CHECK-LABEL: integer_control:
; CHECK: add x0, x0, #1
; CHECK-NEXT: ret
define i64 @integer_control(i64 %value) {
  %result = add i64 %value, 1
  ret i64 %result
}

declare i64 @llvm.aarch64.get.fpsr()
