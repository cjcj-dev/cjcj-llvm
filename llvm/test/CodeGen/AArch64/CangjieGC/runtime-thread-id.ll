; RUN: llc --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu -filetype=obj < %s -o %t.o
; RUN: llvm-objdump -d %t.o | FileCheck %s --check-prefix=ARM
; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu < %s | FileCheck %s --check-prefix=X86
; RUN: llc --cangjie-pipeline -mtriple=x86_64-pc-windows-msvc < %s | FileCheck %s --check-prefix=WIN
; REQUIRES: aarch64-registered-target, x86-registered-target
;
; Decode the object, not assembly spelling: CBZW with an X9 operand can print
; misleading assembly. A nonnull CJThread pointer may have zero low 32 bits.
; ARM-LABEL: <thread_id>:
; ARM: ldr x9, [x28, #16]
; ARM-NEXT: cbz x9,
; ARM-NEXT: ldr x9, [x9, #456]
; X86-LABEL: thread_id:
; X86: movq 16(%r15), %rax
; X86-NEXT: testq %rax, %rax
; X86-NEXT: je
; X86-NEXT: movq 336(%rax), %rax
; WIN-LABEL: thread_id:
; WIN: movq 16(%r15), %rax
; WIN-NEXT: testq %rax, %rax
; WIN-NEXT: je
; WIN-NEXT: movq 536(%rax), %rax

define i64 @thread_id() #0 {
  %id = call cangjiegccc i64 @GetCJThreadIdForMutexOpt()
  ret i64 %id
}
declare cangjiegccc i64 @GetCJThreadIdForMutexOpt() #1
attributes #0 = { "leaf-function" }
attributes #1 = { "gc-leaf-function" "cj-runtime" }
