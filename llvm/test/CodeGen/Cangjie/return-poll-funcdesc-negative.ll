; REQUIRES: x86-registered-target, aarch64-registered-target
; RUN: llc --cangjie-pipeline -no-stacktrace-info -mtriple=x86_64-unknown-linux-gnu %S/return-poll-funcdesc.ll -o %t.elf
; RUN: FileCheck %s --check-prefixes=META,ELF < %t.elf
; RUN: FileCheck %s --check-prefix=NOPOLL < %t.elf
; RUN: FileCheck %s --check-prefix=LEAF < %t.elf
; RUN: llc --cangjie-pipeline -no-stacktrace-info -mtriple=arm64-apple-macosx15.0 %S/return-poll-funcdesc.ll -o %t.macho
; RUN: FileCheck %s --check-prefixes=META,MACHO < %t.macho
; RUN: FileCheck %s --check-prefix=LEAF < %t.macho
;
; Independent negative controls must stay green when eligible polls or their
; metadata bit are cut. LEAF scans the entire output, not just its final table.
; LEAF-NOT: .Lmethod_desc.{{(returnpoll._)?}}leaf:
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
; META-NEXT: .{{long|word}} 0
; MACHO-NEXT: .{{long|word}} 0
