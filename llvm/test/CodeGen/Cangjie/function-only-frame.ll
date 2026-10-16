; REQUIRES: x86-registered-target
; RUN: llc --cangjie-pipeline --frame-pointer=non-leaf -mtriple=x86_64-unknown-linux-gnu -O2 %s -o - | FileCheck %s
; RUN: llc --cangjie-pipeline --frame-pointer=non-leaf -mtriple=x86_64-apple-macosx15.0 -O2 %s -o - | FileCheck %s --check-prefix=MACHO
; RUN: llc --cangjie-pipeline --frame-pointer=non-leaf -mtriple=x86_64-pc-windows-msvc -O2 %s -o - | FileCheck %s --check-prefix=WIN
; CHECK-LABEL: managed_frame:
; CHECK: pushq %rbp
; CHECK: movq %rsp, %rbp
; CHECK: pushq %r15
; CHECK: pushq %r14
; CHECK: pushq %r13
; CHECK: pushq %r12
; CHECK: pushq %rbx
; CHECK-LABEL: native_frame:
; CHECK-NOT: movq %rsp, %rbp
; CHECK: retq
; MACHO-LABEL: _managed_frame:
; MACHO: pushq %rbp
; MACHO: movq %rsp, %rbp
; WIN-LABEL: managed_frame:
; WIN: pushq %rbp
; WIN: movq %rsp, %rbp
; WIN: #CalleeSaveReg: (0x79=121), rbx, r12, r13, r14, r15, offsets(without sign): [40, 32, 24, 16, 8]
; WIN: #StackMapItem nums:0
; CHECK-LABEL: .Lstack_map.managed_frame:
; CHECK: #CalleeSaveReg: (0x1f=31), rbx, r12, r13, r14, r15, offsets(without sign): [48, 40, 32, 24, 16]
; CHECK: #StackMapItem nums:0

define void @managed_frame() "cj_fast_call" "frame-pointer"="non-leaf" gc "cangjie" {
  call void asm sideeffect "", "~{rbx},~{r12},~{r13},~{r14},~{r15}"()
  ret void
}

define void @native_frame() "frame-pointer"="non-leaf" {
  call void asm sideeffect "", "~{rbx},~{rbp},~{r12},~{r13},~{r14},~{r15}"()
  ret void
}

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"function_only_frame"}
