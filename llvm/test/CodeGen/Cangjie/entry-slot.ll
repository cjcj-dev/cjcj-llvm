; REQUIRES: x86-registered-target, aarch64-registered-target
; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu %S/Inputs/entry-slot.ll -o - | FileCheck %s --check-prefixes=SLOT,ALL
; RUN: llc --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu %S/Inputs/entry-slot.ll -o - | FileCheck %s --check-prefixes=SLOT,ALL
; RUN: llc --cangjie-pipeline -mtriple=x86_64-pc-windows-msvc %S/Inputs/entry-slot.ll -o - | FileCheck %s --check-prefixes=SLOT,ALL
; RUN: llc --cangjie-pipeline -mtriple=aarch64-pc-windows-msvc %S/Inputs/entry-slot.ll -o - | FileCheck %s --check-prefixes=SLOT,ALL
; RUN: llc --cangjie-pipeline -mtriple=x86_64-apple-macosx15.0 %S/Inputs/entry-slot.ll -o - | FileCheck %s --check-prefixes=MACHO,ALL
; RUN: llc --cangjie-pipeline -mtriple=arm64-apple-macosx15.0 %S/Inputs/entry-slot.ll -o - | FileCheck %s --check-prefixes=MACHO,ALL
;
; Every managed slot refers to a real descriptor, including legacy leaf input.
; Native functions and Mach-O do not gain entry slots.
; SLOT: .{{long|word}} .Lmethod_desc.slot_neighbor-
; SLOT-NEXT: slot_neighbor:
; MACHO-LABEL: {{^_slot_neighbor:}}
; ALL: .globl {{_?}}slot_leaf
; SLOT: .{{long|word}} .Lmethod_desc.slot_leaf-
; SLOT-NEXT: slot_leaf:
; MACHO-NOT: .{{long|word}}
; MACHO-LABEL: {{^_slot_leaf:}}
; ALL: .globl {{_?}}slot_plain
; ALL-NOT: .{{long|word}}
; ALL-LABEL: {{^_?slot_plain:}}
; ALL: .Lmethod_desc.{{.*}}slot_neighbor:
; ALL: .Lmethod_desc.{{.*}}slot_leaf:
