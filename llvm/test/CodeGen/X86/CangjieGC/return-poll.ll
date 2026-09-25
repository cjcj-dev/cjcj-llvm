; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu -o - < %s | FileCheck %s --check-prefixes=X86,BOTH
; RUN: llc --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu -o - < %s | FileCheck %s --check-prefixes=A64,BOTH
;
; HotSpot macroAssembler_x86.cpp:2590-2596 and
; macroAssembler_aarch64.cpp:515-521: after the frame is gone, compare SP
; unsigned-above the shared poll word. The slow path is an out-of-line
; branch that publishes the return-site PC and tail-jumps, matching
; C2SafepointPollStub (x86_64.ad return poll / aarch64 safepoint poll).
; A direct PLT branch would clobber that PC or push, so the branch is a
; GOT load. gc-leaf-function stays on the existing no-poll path.

; BOTH-LABEL: void_ret:
; X86: cmpq 48(%r15), %rsp
; X86-NEXT: ja
; X86-NEXT: retq
; X86: leaq .Lcj_return_pc{{[0-9]+}}(%rip), %r11
; X86-NEXT: jmpq *CJ_MCC_HandleReturnSafepoint@GOTPCREL(%rip)
; A64: ldr x16, [x28, #48]
; A64-NEXT: cmp sp, x16
; A64-NEXT: b.hi
; A64: {{^[[:space:]]*ret$}}
; A64: adrp x17, :got:CJ_MCC_HandleReturnSafepoint
; A64: ldr x17, [x17, :got_lo12:CJ_MCC_HandleReturnSafepoint]
; A64: adr x16, .Lcj_return_pc{{[0-9]+}}
; A64-NEXT: br x17
define void @void_ret() gc "cangjie" {
  ret void
}

; BOTH-LABEL: ref_ret:
; X86: movq %rdi, %rax
; X86: cmpq 48(%r15), %rsp
; X86-NEXT: ja
; X86-NEXT: retq
; A64: ldr x16, [x28, #48]
; A64-NEXT: cmp sp, x16
; A64-NEXT: b.hi
; A64: {{^[[:space:]]*ret$}}
define i8 addrspace(1)* @ref_ret(i8 addrspace(1)* %p) gc "cangjie" {
  ret i8 addrspace(1)* %p
}

; BOTH-LABEL: leaf_ret:
; BOTH-NOT: CJ_MCC_HandleReturnSafepoint
; X86: retq
; A64: ret
define void @leaf_ret() #0 gc "cangjie" {
  ret void
}
attributes #0 = { "gc-leaf-function" }

; BOTH-LABEL: plain_ret:
; BOTH-NOT: CJ_MCC_HandleReturnSafepoint
; X86: retq
; A64: {{^[[:space:]]*ret$}}
define void @plain_ret() {
  ret void
}

; Stack maps are emitted after every function, outside the per-function
; CHECK-LABEL windows above.
; BOTH: .Lstack_map.void_ret:
; BOTH: RegNums: 0
; BOTH: .Lstack_map.ref_ret:
; X86: rax
; A64: x0
; BOTH-NOT: .Lstack_map.leaf_ret:
; BOTH-NOT: .Lstack_map.plain_ret:
