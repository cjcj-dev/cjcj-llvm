; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu -o - < %s | FileCheck %s --check-prefixes=X86,BOTH
; RUN: llc --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu -o - < %s | FileCheck %s --check-prefixes=A64,BOTH
;
; HotSpot macroAssembler_x86.cpp:2590-2596 and
; macroAssembler_aarch64.cpp:515-521: after the frame is gone, compare SP
; unsigned-above the shared poll word. C2SafepointPollStub
; (c2_CodeStubs_x86.cpp:45-48) records the safepoint PC then jumps.
; This AOT image has no CodeCache, so the stub also publishes startPC
; (the .Lfunc_begin the frame stores, AArch64AsmPrinter.cpp:1577-1583)
; in r10/x17, and the return-site PC in r11/x16. A PLT veneer would
; clobber x16/x17, so AArch64 loads the handler into x9 and br x9.
; gc-leaf-function stays on the existing no-poll path.

; BOTH-LABEL: void_ret:
; X86: .Lfunc_begin[[VOID:[0-9]+]]:
; X86: cmpq 48(%r15), %rsp
; X86-NEXT: ja
; X86-NEXT: retq
; X86: leaq .Lfunc_begin[[VOID]](%rip), %r10
; X86-NEXT: leaq .Lcj_return_pc{{[0-9]+}}(%rip), %r11
; X86-NEXT: jmpq *CJ_MCC_HandleReturnSafepoint@GOTPCREL(%rip)
; A64: .Lfunc_begin[[VOID:[0-9]+]]:
; A64: ldr x16, [x28, #48]
; A64-NEXT: cmp sp, x16
; A64-NEXT: b.hi
; A64: {{^[[:space:]]*ret$}}
; A64: adrp x9, :got:CJ_MCC_HandleReturnSafepoint
; A64-NEXT: ldr x9, [x9, :got_lo12:CJ_MCC_HandleReturnSafepoint]
; A64-NEXT: adr x17, .Lfunc_begin[[VOID]]
; A64-NEXT: adr x16, .Lcj_return_pc{{[0-9]+}}
; A64-NEXT: br x9
define void @void_ret() gc "cangjie" {
  ret void
}

; BOTH-LABEL: ref_ret:
; X86: .Lfunc_begin[[REF:[0-9]+]]:
; X86: movq %rdi, %rax
; X86: cmpq 48(%r15), %rsp
; X86-NEXT: ja
; X86-NEXT: retq
; X86: leaq .Lfunc_begin[[REF]](%rip), %r10
; X86-NEXT: leaq .Lcj_return_pc{{[0-9]+}}(%rip), %r11
; A64: .Lfunc_begin[[REF:[0-9]+]]:
; A64: ldr x16, [x28, #48]
; A64-NEXT: cmp sp, x16
; A64-NEXT: b.hi
; A64: {{^[[:space:]]*ret$}}
; A64: adr x17, .Lfunc_begin[[REF]]
; A64-NEXT: adr x16, .Lcj_return_pc{{[0-9]+}}
; A64-NEXT: br x9
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
