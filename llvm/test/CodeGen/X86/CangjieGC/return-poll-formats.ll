; REQUIRES: x86-registered-target, aarch64-registered-target
; RUN: llc --cangjie-pipeline -mtriple=aarch64-pc-windows-msvc < %s | FileCheck %s --check-prefix=NO-POLL
; RUN: llc --cangjie-pipeline -mtriple=x86_64 < %s | FileCheck %s --check-prefix=NO-POLL
; RUN: llc --cangjie-pipeline -mtriple=aarch64 < %s | FileCheck %s --check-prefix=NO-POLL
; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu < %s | FileCheck %s --check-prefixes=X86,X86-ELF
; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu -filetype=obj < %s -o %t.x86_64-unknown-linux-gnu.o
; RUN: llvm-objdump -r %t.x86_64-unknown-linux-gnu.o | FileCheck %s --check-prefix=X86-ELF-RELOC
; RUN: llc --cangjie-pipeline -mtriple=x86_64-apple-macosx11.0 < %s | FileCheck %s --check-prefixes=X86,X86-MACH
; RUN: llc --cangjie-pipeline -mtriple=x86_64-apple-macosx11.0 -filetype=obj < %s -o %t.x86_64-apple-macosx11.0.o
; RUN: llvm-objdump -r %t.x86_64-apple-macosx11.0.o | FileCheck %s --check-prefix=X86-MACH-RELOC
; RUN: llc --cangjie-pipeline -mtriple=x86_64-apple-ios14.0 < %s | FileCheck %s --check-prefixes=X86,X86-MACH
; RUN: llc --cangjie-pipeline -mtriple=x86_64-apple-ios14.0 -filetype=obj < %s -o %t.x86_64-apple-ios14.0.o
; RUN: llvm-objdump -r %t.x86_64-apple-ios14.0.o | FileCheck %s --check-prefix=X86-MACH-RELOC
; RUN: llc --cangjie-pipeline -mtriple=x86_64-pc-windows-msvc < %s | FileCheck %s --check-prefixes=X86,X86-COFF
; RUN: llc --cangjie-pipeline -mtriple=x86_64-pc-windows-msvc -filetype=obj < %s -o %t.x86_64-pc-windows-msvc.o
; RUN: llvm-objdump -r %t.x86_64-pc-windows-msvc.o | FileCheck %s --check-prefix=X86-COFF-RELOC
; RUN: llc --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu < %s | FileCheck %s --check-prefixes=A64,A64-ELF
; RUN: llc --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu -filetype=obj < %s -o %t.aarch64-unknown-linux-gnu.o
; RUN: llvm-objdump -r %t.aarch64-unknown-linux-gnu.o | FileCheck %s --check-prefix=A64-ELF-RELOC
; RUN: llc --cangjie-pipeline -mtriple=aarch64-apple-macosx11.0 < %s | FileCheck %s --check-prefixes=A64,A64-MACH
; RUN: llc --cangjie-pipeline -mtriple=aarch64-apple-macosx11.0 -filetype=obj < %s -o %t.aarch64-apple-macosx11.0.o
; RUN: llvm-objdump -r %t.aarch64-apple-macosx11.0.o | FileCheck %s --check-prefix=A64-MACH-RELOC
; RUN: llc --cangjie-pipeline -mtriple=aarch64-apple-ios14.0 < %s | FileCheck %s --check-prefixes=A64,A64-MACH
; RUN: llc --cangjie-pipeline -mtriple=aarch64-apple-ios14.0 -filetype=obj < %s -o %t.aarch64-apple-ios14.0.o
; RUN: llvm-objdump -r %t.aarch64-apple-ios14.0.o | FileCheck %s --check-prefix=A64-MACH-RELOC
;
; Windows ARM64 is outside the runtime platform matrix.
; Address materialization follows X86MCInstLower and
; AArch64MCInstLower::lowerSymbolOperand{MachO,COFF,ELF}. The indirect
; transfer must preserve the return registers and r10/r11 or x17/x16.
; Check the actual object relocations as well as the instruction operands.

; NO-POLL: ref_ret:
; NO-POLL-NOT: CJ_MCC_HandleReturnSafepoint
; NO-POLL-NOT: cj_return_pc
; X86-LABEL: ref_ret:
; X86: cmpq {{[0-9]+}}(%r15), %rsp
; X86-NEXT: ja
; X86-NEXT: retq
; X86: leaq {{.*}}func_begin{{[0-9]+}}(%rip), %r10
; X86-NEXT: leaq {{.*}}cj_return_pc{{[0-9]+}}(%rip), %r11
; X86-ELF-NEXT: jmpq *CJ_MCC_HandleReturnSafepoint@GOTPCREL(%rip)
; X86-MACH-NEXT: jmpq *_CJ_MCC_HandleReturnSafepoint@GOTPCREL(%rip)
; X86-COFF-NEXT: jmpq *__imp_CJ_MCC_HandleReturnSafepoint(%rip)
; A64-LABEL: ref_ret:
; A64: ldr x16, [x28, #{{[0-9]+}}]
; A64-NEXT: cmp sp, x16
; A64-NEXT: b.hi
; A64: {{^[[:space:]]*ret$}}
; A64-ELF: adrp x9, :got:CJ_MCC_HandleReturnSafepoint
; A64-ELF-NEXT: ldr x9, [x9, :got_lo12:CJ_MCC_HandleReturnSafepoint]
; A64-MACH: adrp x9, _CJ_MCC_HandleReturnSafepoint@GOTPAGE
; A64-MACH-NEXT: ldr x9, [x9, _CJ_MCC_HandleReturnSafepoint@GOTPAGEOFF]
; A64: adr x17, {{.*}}func_begin{{[0-9]+}}
; A64-NEXT: adr x16, {{.*}}cj_return_pc{{[0-9]+}}
; A64-NEXT: br x9
define i8 addrspace(1)* @ref_ret(i8 addrspace(1)* %p) gc "cangjie" {
  ret i8 addrspace(1)* %p
}

; X86-LABEL: leaf_ret:
; X86-NOT: cj_return
; X86: retq
; A64-LABEL: leaf_ret:
; A64-NOT: cj_return
; A64: ret
define void @leaf_ret() #0 gc "cangjie" {
  ret void
}
attributes #0 = { "gc-leaf-function" }

; X86: RegNums: 1
; X86-NEXT: {{.*}}rax
; A64: RegNums: 1
; A64-NEXT: {{.*}}x0

; X86-ELF-RELOC: R_X86_64_GOTPCREL{{.*}} CJ_MCC_HandleReturnSafepoint
; X86-MACH-RELOC: X86_64_RELOC_GOT{{.*}} _CJ_MCC_HandleReturnSafepoint
; X86-COFF-RELOC: IMAGE_REL_AMD64_REL32{{.*}} __imp_CJ_MCC_HandleReturnSafepoint
; A64-ELF-RELOC: R_AARCH64_ADR_GOT_PAGE{{.*}} CJ_MCC_HandleReturnSafepoint
; A64-ELF-RELOC: R_AARCH64_LD64_GOT_LO12_NC{{.*}} CJ_MCC_HandleReturnSafepoint
; A64-MACH-RELOC-DAG: ARM64_RELOC_GOT_LOAD_PAGE21{{.*}} _CJ_MCC_HandleReturnSafepoint
; A64-MACH-RELOC-DAG: ARM64_RELOC_GOT_LOAD_PAGEOFF12{{.*}} _CJ_MCC_HandleReturnSafepoint

!llvm.module.flags = !{!0}
!0 = !{i32 2, !"Cangjie_PACKAGE_ID", !"return_poll_formats"}
