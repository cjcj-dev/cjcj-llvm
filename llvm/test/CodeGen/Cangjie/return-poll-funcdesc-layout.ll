; REQUIRES: x86-registered-target
; RUN: llc --cangjie-pipeline -no-stacktrace-info -mtriple=x86_64-unknown-linux-gnu -filetype=obj %s -o %t.elf
; RUN: llvm-objdump -s --section=.cjmetadata.methodinfo %t.elf | FileCheck %s --check-prefix=ELF
; RUN: llc --cangjie-pipeline -no-stacktrace-info -mtriple=x86_64-apple-macosx15.0 -filetype=obj %s -o %t.macho
; RUN: llvm-objdump -s --section=__cjmethodinfo %t.macho | FileCheck %s --check-prefix=MACHO
;
; Read the emitted object bytes, independently of assembly directives.
; The return-poll word is at offset 28 (ELF) or 32 (Mach-O).
; ELF: 0010 00000000 00000000 {{[0-9a-f]{8}}} 01000000
; MACHO: 0020 01000000 00000000

declare void @callee() "gc-leaf-function"
define void @poll() gc "cangjie" {
  call void @callee()
  ret void
}
