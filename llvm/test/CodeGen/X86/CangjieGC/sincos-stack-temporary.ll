; RUN: llc --cangjie-pipeline -mtriple=x86_64-pc-linux-gnu -O2 < %s | FileCheck %s

declare double @llvm.sin.f64(double)
declare double @llvm.cos.f64(double)
declare void @safepoint()

define double @sincos_stack_temporary(double %x) gc "cangjie" {
; CHECK-LABEL: sincos_stack_temporary:
; CHECK: callq sincos@PLT
; CHECK: callq safepoint@PLT
entry:
  %sin = call double @llvm.sin.f64(double %x)
  %cos = call double @llvm.cos.f64(double %x)
  call void @safepoint()
  %sum = fadd double %sin, %cos
  ret double %sum
}
