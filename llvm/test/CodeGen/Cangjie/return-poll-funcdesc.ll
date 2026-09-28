; REQUIRES: x86-registered-target, aarch64-registered-target
; RUN: llc --cangjie-pipeline -no-stacktrace-info -mtriple=x86_64-unknown-linux-gnu %s -o %t.elf
; RUN: FileCheck %s --check-prefixes=META,ELF < %t.elf
; RUN: FileCheck %s --check-prefix=POLL < %t.elf
; RUN: llc --cangjie-pipeline -no-stacktrace-info -mtriple=arm64-apple-macosx15.0 %s -o %t.macho
; RUN: FileCheck %s --check-prefixes=META,MACHO < %t.macho
; RUN: FileCheck %s --check-prefix=A64 < %t.macho
; RUN: llc --cangjie-pipeline -no-stacktrace-info -mtriple=aarch64-unknown-linux-gnu %s -o - | FileCheck %s --check-prefixes=META,ELF
; RUN: llc --cangjie-pipeline -no-stacktrace-info -mtriple=x86_64-apple-macosx15.0 %s -o - | FileCheck %s --check-prefixes=META,MACHO
; RUN: llc --cangjie-pipeline -no-stacktrace-info -mtriple=x86_64-pc-windows-msvc %s -o - | FileCheck %s --check-prefixes=META,ELF
;
; The descriptor word and RET poll share one eligibility decision. The four
; stacktrace words and EH offset retain their existing positions. Checking
; metadata separately prevents an instruction failure from hiding its result.
;
; POLL-LABEL: poll:
; POLL: cmpq {{[0-9]+}}(%r15), %rsp
; A64-LABEL: _poll:
; A64: cmp sp, x16

declare void @callee() #0

define void @poll() gc "cangjie" {
  call void @callee()
  ret void
}

define void @no_poll() #0 gc "cangjie" {
  call void @callee()
  ret void
}

define void @fast() #1 gc "cangjie" {
  call void @callee()
  ret void
}

define void @bare() #2 gc "cangjie" {
  call void asm sideeffect "", ""()
  ret void
}

define void @leaf() #3 gc "cangjie" { ret void }

define void @init() #4 gc "cangjie" {
  call void @callee()
  ret void
}

attributes #0 = { "gc-leaf-function" }
attributes #1 = { "cj_fast_call" }
attributes #2 = { naked }
attributes #3 = { "leaf-function" }
attributes #4 = { "cjinit" }
!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"returnpoll"}

; META-LABEL: .Lmethod_desc.{{(returnpoll._)?}}poll:
; META-NEXT: .long {{.*}}
; META-NEXT: .long {{.*}}
; META-NEXT: .long 0
; META-NEXT: .long 0
; META-NEXT: .long 0
; META-NEXT: .long 0
; ELF-NEXT: .long {{.*}}
; MACHO-NEXT: .quad {{.*}}
; META-NEXT: .long 1
; MACHO-NEXT: .long 0
; META-LABEL: .Lmethod_desc.{{(returnpoll._)?}}no_poll:
; META-NEXT: .long {{.*}}
; META-NEXT: .long {{.*}}
; META-NEXT: .long 0
; META-NEXT: .long 0
; META-NEXT: .long 0
; META-NEXT: .long 0
; ELF-NEXT: .long {{.*}}
; MACHO-NEXT: .quad {{.*}}
; META-NEXT: .long 0
; MACHO-NEXT: .long 0
; META-LABEL: .Lmethod_desc.{{(returnpoll._)?}}fast:
; META-NEXT: .long {{.*}}
; META-NEXT: .long {{.*}}
; META-NEXT: .long 0
; META-NEXT: .long 0
; META-NEXT: .long 0
; META-NEXT: .long 0
; ELF-NEXT: .long {{.*}}
; MACHO-NEXT: .quad {{.*}}
; META-NEXT: .long 0
; MACHO-NEXT: .long 0
; META-LABEL: .Lmethod_desc.{{(returnpoll._)?}}bare:
; META-NEXT: .long {{.*}}
; META-NEXT: .long {{.*}}
; META-NEXT: .long 0
; META-NEXT: .long 0
; META-NEXT: .long 0
; META-NEXT: .long 0
; ELF-NEXT: .long {{.*}}
; MACHO-NEXT: .quad {{.*}}
; META-NEXT: .long 0
; MACHO-NEXT: .long 0
; META-LABEL: .Lmethod_desc.{{(returnpoll._)?}}init:
; META-NEXT: .long {{.*}}
; META-NEXT: .long {{.*}}
; META-NEXT: .long 0
; META-NEXT: .long 0
; META-NEXT: .long 0
; META-NEXT: .long 0
; ELF-NEXT: .long {{.*}}
; MACHO-NEXT: .quad {{.*}}
; META-NEXT: .long 1
; MACHO-NEXT: .long 0
; META-NOT: .Lmethod_desc.{{(returnpoll._)?}}leaf:
