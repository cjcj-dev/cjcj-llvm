; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu < %s | FileCheck %s --check-prefix=X86
; RUN: llc --cangjie-pipeline -mtriple=x86_64-pc-windows-msvc < %s | FileCheck %s --check-prefix=WIN
; RUN: llc --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu < %s | FileCheck %s --check-prefix=ARM
; REQUIRES: x86-registered-target, aarch64-registered-target
;
; HotSpot barrierSetC2.cpp:763-780,810: load and update the inline TLAB.
; NEXT checks bind the emitted producer/consumer sequence, including the absence
; of the former descriptor load. The array label span has twelve instructions.
;
; X86-LABEL: allocate_object:
; X86:       movq (%r15), %rdx
; X86-NEXT:  movq (%rdx), %rax
; X86-NEXT:  movq 8(%rdx), %rcx
; X86-NEXT:  leaq (%rax,%rsi), %r8
; X86-NEXT:  cmpq %rcx, %r8
; X86-NEXT:  jg CJ_MCC_NewObject
; X86-NEXT:  movq %rdi, (%rax)
; X86-NEXT:  movq %r8, (%rdx)
; WIN-LABEL: allocate_object:
; WIN:       movq (%r15), %r9
; WIN-NEXT:  movq (%r9), %rax
; WIN-NEXT:  movq 8(%r9), %r10
; WIN-NEXT:  leaq (%rax,%rdx), %r8
; WIN-NEXT:  cmpq %r10, %r8
; WIN-NEXT:  jg CJ_MCC_NewObject
; WIN-NEXT:  movq %rcx, (%rax)
; WIN-NEXT:  movq %r8, (%r9)
; ARM-LABEL: allocate_object:
; ARM:       ldr x2, [x28]
; ARM-NEXT:  ldr x3, [x2]
; ARM-NEXT:  ldr x4, [x2, #8]
; ARM-NEXT:  add x5, x3, x1
; ARM-NEXT:  cmp x5, x4
; ARM-NEXT:  b.gt
; ARM-NEXT:  str x0, [x3]
; ARM-NEXT:  str x5, [x2]
;
; X86-LABEL: allocate_array:
; X86:       movq (%r15), %r9
; X86-NEXT:  movq (%r9), %rax
; X86-NEXT:  movq 8(%r9), %r10
; X86-NEXT:  leaq (%rax,%rdx), %r8
; X86-NEXT:  cmpq %r10, %r8
; X86-NEXT:  jg
; X86-NEXT:  movq %rdi, (%rax)
; X86-NEXT:  movq %rsi, 8(%rax)
; X86-NEXT:  movq %r8, (%r9)
; WIN-LABEL: allocate_array:
; WIN:       movq (%r15), %r9
; WIN-NEXT:  movq (%r9), %rax
; WIN-NEXT:  movq 8(%r9), %r10
; WIN-NEXT:  leaq (%rax,%r8), %r11
; WIN-NEXT:  cmpq %r10, %r11
; WIN-NEXT:  jg
; WIN-NEXT:  movq %rcx, (%rax)
; WIN-NEXT:  movq %rdx, 8(%rax)
; WIN-NEXT:  movq %r11, (%r9)
; ARM-LABEL: allocate_array:
; ARM:       .LNewArrayFastPath{{[0-9]+}}:
; ARM-NEXT:  ldr x4, [x28]
; ARM-NEXT:  ldr x5, [x4]
; ARM-NEXT:  ldr x6, [x4, #8]
; ARM-NEXT:  add x7, x5, x2
; ARM-NEXT:  cmp x7, x6
; ARM-NEXT:  b.gt .LNewArraySlowPath{{[0-9]+}}
; ARM-NEXT:  str x0, [x5]
; ARM-NEXT:  str x1, [x5, #8]
; ARM-NEXT:  str x7, [x4]
; ARM-NEXT:  mov x0, x5
; ARM-NEXT:  b .LNewArrayFin{{[0-9]+}}
; ARM-NEXT:  .LNewArraySlowPath{{[0-9]+}}:
; ARM-NEXT:  bl CJ_MCC_NewArray
; ARM-NEXT:  .LNewArrayFin{{[0-9]+}}:

target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
define i8 addrspace(1)* @allocate_object(i8* %type, i32 %size) gc "cangjie" {
  %p = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* %type, i32 %size)
  ret i8 addrspace(1)* %p
}
define i8 addrspace(1)* @allocate_array(i8* %type, i64 %length, i64 %size) gc "cangjie" {
  %token = call token (...) @llvm.cj.gc.statepoint(i64 6, i32 0, i8 addrspace(1)* (i8*, i64, i64)* @CJ_MCC_NewArray, i32 3, i32 0, i8* %type, i64 %length, i64 %size)
  %p = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  ret i8 addrspace(1)* %p
}
declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare i8 addrspace(1)* @CJ_MCC_NewArray(i8*, i64, i64)
!0 = !{}

declare token @llvm.cj.gc.statepoint(...)
declare i8 addrspace(1)* @llvm.cj.gc.result(token)
