; RUN: opt --cangjie-pipeline -opaque-pointers=0 -passes='default<O2>' -S %s -o %t.ll
; RUN: FileCheck %s --check-prefix=IR < %t.ll
; RUN: llc --cangjie-pipeline -opaque-pointers=0 -O2 -mtriple=aarch64-unknown-linux-gnu %t.ll -o - | FileCheck %s --check-prefix=ARM
; RUN: opt --cangjie-pipeline -opaque-pointers=0 -mtriple=x86_64-unknown-linux-gnu -passes='default<O2>' -S %s -o %t.x86.ll
; RUN: FileCheck %s --check-prefix=X86-IR < %t.x86.ll
; RUN: llc --cangjie-pipeline -opaque-pointers=0 -O2 -mtriple=x86_64-unknown-linux-gnu %t.x86.ll -o - | FileCheck %s --check-prefix=X86
; REQUIRES: aarch64-registered-target, x86-registered-target
;
; Exercise the real FP overflow-check producer, rather than feeding an
; artificial MRS to MachineInstr. The converted integer is an extra MRS
; operand, keeping the FPSR read scheduled after FCVTZS. Its opcode must be
; recognized by TargetLowering in both InstrEmitter and addOperand.
target triple = "aarch64-unknown-linux-gnu"

; IR-LABEL: define i64 @checked_fp_to_int(
; IR: %converted = fptosi double %value to i64
; IR-NEXT: {{.*}}call i64 @llvm.cj.get.fp.state.i64(i64 %converted)
; IR: and i64 {{.*}}, 1
; IR: fp.convert.exception:
; IR: call void @llvm.cj.reset.fp.state()
; ARM-LABEL: checked_fp_to_int:
; ARM: fcvtzs
; ARM: mrs {{x[0-9]+}}, FPSR
; ARM: msr FPSR, xzr
; X86-IR-LABEL: define i64 @checked_fp_to_int(
; X86-IR-NOT: @llvm.cj.get.fp.state
; X86-IR: [[EXP:%.*]] = and i64 %bits, 9218868437227405312
; X86-IR: [[FINITE:%.*]] = icmp ne i64 [[EXP]], 9218868437227405312
; X86-IR: [[MIN:%.*]] = fcmp ogt double %value, 0xC3E0000000000001
; X86-IR: [[LOW:%.*]] = select i1 [[FINITE]], i1 [[MIN]], i1 false
; X86-IR: [[MAX:%.*]] = fcmp olt double %value, 0x43E0000000000000
; X86-IR: [[RANGE:%.*]] = select i1 [[LOW]], i1 [[MAX]], i1 false
; X86-IR: [[CVT:%.*]] = fptosi double %value to i64
; X86-IR-NOT: @llvm.cj.get.fp.state
; X86-IR: [[RESULT:%.*]] = select i1 [[RANGE]], i64 [[CVT]], i64 0
; X86-IR: ret i64 [[RESULT]]
; X86-IR-NOT: @llvm.cj.get.fp.state
; X86-LABEL: checked_fp_to_int:
; X86: cvttsd2si
define i64 @checked_fp_to_int(double %value) gc "cangjie" {
entry:
  %bits = bitcast double %value to i64
  %exponent = and i64 %bits, 9218868437227405312
  %finite = icmp ne i64 %exponent, 9218868437227405312
  br i1 %finite, label %not.inf.nan, label %overflow
not.inf.nan:
  %above_min = fcmp olt double 0xC3E0000000000001, %value
  br i1 %above_min, label %lower.bound.ok, label %overflow
lower.bound.ok:
  %below_max = fcmp olt double %value, 0x43E0000000000000
  br i1 %below_max, label %upper.bound.ok, label %overflow
upper.bound.ok:
  %converted = fptosi double %value to i64
  ret i64 %converted
overflow:
  ret i64 0
}

; ARM-LABEL: integer_control:
; ARM: add x0, x0, #1
; ARM: ret
; X86-LABEL: integer_control:
; X86: retq
define i64 @integer_control(i64 %value) {
  %result = add i64 %value, 1
  ret i64 %result
}
