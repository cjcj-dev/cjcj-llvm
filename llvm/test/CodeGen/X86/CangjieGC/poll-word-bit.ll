; RUN: opt -S --cangjie-pipeline -mtriple=x86_64 -enable-new-pm=0 -place-safepoints -cj-rewrite-statepoint < %s > %t
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -cj-safepoint-outline=false -o - < %t | FileCheck %s --check-prefix=X86-INLINE
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -cj-safepoint-outline=true -o - < %t | FileCheck %s --check-prefix=X86-OUTLINE
; RUN: llc --cangjie-pipeline -mtriple=aarch64 -cj-safepoint-outline=false -o - < %t | FileCheck %s --check-prefix=A64-INLINE
; RUN: llc --cangjie-pipeline -mtriple=aarch64 -cj-safepoint-outline=true -o - < %t | FileCheck %s --check-prefix=A64-OUTLINE
;
; Normal polls inspect only the armed bit of the shared poll word. A nonzero
; disarmed sentinel or an aligned stack watermark must not request a handshake.
; HotSpot macroAssembler_x86.cpp:2590-2600 and
; macroAssembler_aarch64.cpp:515-525 use this same at_return split.
;
; X86-INLINE-LABEL: poll_word:
; X86-INLINE: movq 48(%r15), %rax
; X86-INLINE-NEXT: testq $1, %rax
; X86-INLINE-NEXT: jne
; X86-OUTLINE: testq $1, 48(%r15)
; X86-OUTLINE-NEXT: jne
; A64-INLINE-LABEL: poll_word:
; A64-INLINE: ldr x9, [x28, #48]
; A64-INLINE-NEXT: tst x9, #0x1
; A64-INLINE-NEXT: b.ne
; A64-OUTLINE: ldr x9, [x28, #48]
; A64-OUTLINE-NEXT: tbnz x9, #0,
define void @poll_word() gc "cangjie" {
  call void @work()
  ret void
}
declare void @work()
