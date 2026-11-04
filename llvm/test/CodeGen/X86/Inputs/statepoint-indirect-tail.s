.text
.globl check_saved
.type check_saved,@function
check_saved:
  pushq %rbx
  pushq %rbp
  pushq %r12
  pushq %r13
  pushq %r14
  pushq %r15
  subq $8, %rsp
  movq $6, (%rsp)
  movq $101, %rbx
  movq $102, %rbp
  movq $103, %r12
  movq $104, %r13
  movq $105, %r14
  leaq c15_tls(%rip), %r15
  leaq expected(%rip), %rdi
  movq $1, %rsi
  movq $2, %rdx
  movq $3, %rcx
  movq $4, %r8
  movq $5, %r9
  call indirect_pressure
  movl $1, %eax
  cmpq $101, %rbx
  jne .Ldone
  cmpq $102, %rbp
  jne .Ldone
  cmpq $103, %r12
  jne .Ldone
  cmpq $104, %r13
  jne .Ldone
  cmpq $105, %r14
  jne .Ldone
  leaq c15_tls(%rip), %r11
  cmpq %r11, %r15
  jne .Ldone
  xorl %eax, %eax
.Ldone:
  addq $8, %rsp
  popq %r15
  popq %r14
  popq %r13
  popq %r12
  popq %rbp
  popq %rbx
  ret
.size check_saved,.-check_saved
.section .note.GNU-stack,"",@progbits

# Finite return-poll fast-path fixture, not a runtime ThreadLocalData object.
# The fixed LLVM X86 return poll only compares RSP with the slot at R15+48.
# All-one slots select fast return; the C handler fails if slow is reached.
.data
.balign 16
.globl c15_tls
c15_tls:
  .rept 64
  .quad -1
  .endr
