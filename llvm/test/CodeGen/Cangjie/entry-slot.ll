; REQUIRES: x86-registered-target, aarch64-registered-target
; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu %S/Inputs/entry-slot.ll -o - | FileCheck %s --check-prefixes=SLOT,ALL
; RUN: llc --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu %S/Inputs/entry-slot.ll -o - | FileCheck %s --check-prefixes=SLOT,ALL
; RUN: llc --cangjie-pipeline -mtriple=x86_64-pc-windows-msvc %S/Inputs/entry-slot.ll -o - | FileCheck %s --check-prefixes=SLOT,ALL
; RUN: llc --cangjie-pipeline -mtriple=aarch64-pc-windows-msvc %S/Inputs/entry-slot.ll -o - | FileCheck %s --check-prefixes=SLOT,ALL
; RUN: llc --cangjie-pipeline -mtriple=x86_64-apple-macosx15.0 %S/Inputs/entry-slot.ll -o - | FileCheck %s --check-prefixes=MACHO,ALL
; RUN: llc --cangjie-pipeline -mtriple=arm64-apple-macosx15.0 %S/Inputs/entry-slot.ll -o - | FileCheck %s --check-prefixes=MACHO,ALL
;
; The non-leaf slot still refers to a real descriptor. The leaf has a slot
; but no descriptor. Native functions and Mach-O do not gain entry slots.
; SLOT: .long .Lmethod_desc.slot_neighbor-
; SLOT-NEXT: slot_neighbor:
; MACHO-LABEL: {{^_slot_neighbor:}}
; ALL: .globl {{_?}}slot_leaf
; SLOT: .long 0
; SLOT-NEXT: slot_leaf:
; MACHO-NOT: .long
; MACHO-LABEL: {{^_slot_leaf:}}
; ALL: .globl {{_?}}slot_plain
; ALL-NOT: .long
; ALL-LABEL: {{^_?slot_plain:}}
; ALL-NOT: .Lmethod_desc.{{.*}}slot_leaf
; ALL: .Lmethod_desc.{{.*}}slot_neighbor:
; ALL-NOT: .Lmethod_desc.{{.*}}slot_leaf
