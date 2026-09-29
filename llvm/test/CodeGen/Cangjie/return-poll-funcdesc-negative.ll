; REQUIRES: x86-registered-target, aarch64-registered-target
; RUN: llc --cangjie-pipeline -no-stacktrace-info -mtriple=x86_64-unknown-linux-gnu %S/return-poll-funcdesc.ll -o %t.elf
; RUN: FileCheck %s --check-prefixes=META,ELF < %t.elf
; RUN: FileCheck %s --check-prefix=NOPOLL < %t.elf
; RUN: FileCheck %s --check-prefix=LEAF < %t.elf
; RUN: llc --cangjie-pipeline -no-stacktrace-info -mtriple=arm64-apple-macosx15.0 %S/return-poll-funcdesc.ll -o %t.macho
; RUN: FileCheck %s --check-prefixes=META,MACHO < %t.macho
; RUN: FileCheck %s --check-prefix=LEAF < %t.macho
; RUN: llc --cangjie-pipeline -no-stacktrace-info -mtriple=aarch64 %S/return-poll-funcdesc.ll -o - | FileCheck %s --check-prefix=NOOS
;
; Independent negative controls must stay green when eligible polls or their
; metadata bit are cut. Legacy leaf input now has real metadata too.
; LEAF-LABEL: .Lmethod_desc.{{(returnpoll._)?}}leaf:
; LEAF-NEXT: .{{long|word}} .Lstack_map.{{_?}}leaf-
; LEAF: .org .Lmethod_desc.{{(returnpoll._)?}}leaf+{{28|32}}, 0
; LEAF-NEXT: .{{long|word}} 1
; NOPOLL-LABEL: no_poll:
; NOPOLL-NOT: cmpq {{[0-9]+}}(%r15), %rsp
; NOPOLL-LABEL: fast:
; NOPOLL-NOT: cmpq {{[0-9]+}}(%r15), %rsp
; NOPOLL-LABEL: bare:
; NOPOLL-NOT: cmpq {{[0-9]+}}(%r15), %rsp
; NOPOLL-LABEL: leaf:
; META-LABEL: .Lmethod_desc.{{(returnpoll._)?}}no_poll:
; META-NEXT: .{{long|word}} {{.*}}
; META-NEXT: .{{long|word}} {{.*}}
; META-NEXT: .{{long|word}} 0
; META-NEXT: .{{long|word}} 0
; META-NEXT: .{{long|word}} 0
; META-NEXT: .{{long|word}} 0
; META-NEXT: {{\.?Ltmp[0-9]+}}:
; ELF-NEXT: .{{long|word}} {{.*}}
; MACHO-NEXT: .quad {{.*}}
; ELF-NEXT: .org .Lmethod_desc.{{.*}}+28, 0
; MACHO-NEXT: .org .Lmethod_desc.{{.*}}+32, 0
; META-NEXT: .{{long|word}} 0
; MACHO-NEXT: .{{long|word}} 0
; META-LABEL: .Lmethod_desc.{{(returnpoll._)?}}fast:
; META-NEXT: .{{long|word}} {{.*}}
; META-NEXT: .{{long|word}} {{.*}}
; META-NEXT: .{{long|word}} 0
; META-NEXT: .{{long|word}} 0
; META-NEXT: .{{long|word}} 0
; META-NEXT: .{{long|word}} 0
; META-NEXT: {{\.?Ltmp[0-9]+}}:
; ELF-NEXT: .{{long|word}} {{.*}}
; MACHO-NEXT: .quad {{.*}}
; ELF-NEXT: .org .Lmethod_desc.{{.*}}+28, 0
; MACHO-NEXT: .org .Lmethod_desc.{{.*}}+32, 0
; META-NEXT: .{{long|word}} 0
; MACHO-NEXT: .{{long|word}} 0
; META-LABEL: .Lmethod_desc.{{(returnpoll._)?}}bare:
; META-NEXT: .{{long|word}} {{.*}}
; META-NEXT: .{{long|word}} {{.*}}
; META-NEXT: .{{long|word}} 0
; META-NEXT: .{{long|word}} 0
; META-NEXT: .{{long|word}} 0
; META-NEXT: .{{long|word}} 0
; META-NEXT: {{\.?Ltmp[0-9]+}}:
; ELF-NEXT: .{{long|word}} {{.*}}
; MACHO-NEXT: .quad {{.*}}
; ELF-NEXT: .org .Lmethod_desc.{{.*}}+28, 0
; MACHO-NEXT: .org .Lmethod_desc.{{.*}}+32, 0
; META-NEXT: .{{long|word}} 0
; MACHO-NEXT: .{{long|word}} 0

; META-LABEL: .Lmethod_desc.{{(returnpoll\.)?}}asm_named:
; META-NEXT: .{{long|word}} {{.*}}
; META-NEXT: .{{long|word}} {{.*}}
; META-NEXT: .{{long|word}} 0
; META-NEXT: .{{long|word}} 0
; META-NEXT: .{{long|word}} 0
; META-NEXT: .{{long|word}} 0
; META-NEXT: {{\.?Ltmp[0-9]+}}:
; ELF-NEXT: .{{long|word}} {{.*}}
; MACHO-NEXT: .quad {{.*}}
; ELF-NEXT: .org .Lmethod_desc.{{.*}}+28, 0
; MACHO-NEXT: .org .Lmethod_desc.{{.*}}+32, 0
; META-NEXT: .{{long|word}} 0
; MACHO-NEXT: .{{long|word}} 0

; NOOS-NOT: CJ_MCC_HandleReturnSafepoint
; NOOS-LABEL: .Lmethod_desc.poll:
; NOOS-NEXT: .word {{.*}}
; NOOS-NEXT: .word {{.*}}
; NOOS-NEXT: .word 0
; NOOS-NEXT: .word 0
; NOOS-NEXT: .word 0
; NOOS-NEXT: .word 0
; NOOS-NEXT: {{\.?Ltmp[0-9]+}}:
; NOOS-NEXT: .word {{.*}}
; NOOS-NEXT: .org .Lmethod_desc.poll+28, 0
; NOOS-NEXT: .word 0
; NOOS-LABEL: .Lmethod_desc.init:
; NOOS-NEXT: .word {{.*}}
; NOOS-NEXT: .word {{.*}}
; NOOS-NEXT: .word 0
; NOOS-NEXT: .word 0
; NOOS-NEXT: .word 0
; NOOS-NEXT: .word 0
; NOOS-NEXT: {{\.?Ltmp[0-9]+}}:
; NOOS-NEXT: .word {{.*}}
; NOOS-NEXT: .org .Lmethod_desc.init+28, 0
; NOOS-NEXT: .word 0
