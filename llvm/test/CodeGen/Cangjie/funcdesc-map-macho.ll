; REQUIRES: aarch64-registered-target, x86-registered-target
; RUN: llc --cangjie-pipeline -mtriple=arm64-apple-macosx15.0 -o - %s | FileCheck %s --check-prefix=MACHO
; RUN: llc --cangjie-pipeline -mtriple=x86_64-apple-macosx15.0 -o - %s | FileCheck %s --check-prefix=MACHO
; RUN: llc --cangjie-pipeline -mtriple=arm64-apple-ios15.0 -o - %s | FileCheck %s --check-prefix=MACHO
; RUN: llc --cangjie-pipeline -mtriple=x86_64-apple-ios15.0-simulator -o - %s | FileCheck %s --check-prefix=MACHO
; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu -o - %s | FileCheck %s --check-prefix=ELF
; RUN: llc --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu -o - %s | FileCheck %s --check-prefix=ELF
;
; Check the real metadata emitter, including the separate cjinit table.
; The native link test also checks relocations against final symbol addresses.
; MACHO: __cjfuncmap
; MACHO: .quad {{.*}}func_begin0
; MACHO-NEXT: .quad .Lmethod_desc.funcmap._map_first
; MACHO: __cjfuncmap
; MACHO: .quad {{.*}}func_begin1
; MACHO-NEXT: .quad .Lmethod_desc.funcmap._map_init
; MACHO-NOT: .quad .Lmethod_desc.funcmap._map_leaf
; MACHO-NOT: .quad .Lmethod_desc.funcmap._map_plain
; ELF-NOT: __cjfuncmap
; ELF: .Lmethod_desc.map_first
; ELF-NOT: __cjfuncmap

define void @map_first() gc "cangjie" { ret void }
define void @map_init() #0 gc "cangjie" { ret void }
define void @map_leaf() #1 gc "cangjie" { ret void }
define void @map_plain() { ret void }
attributes #0 = { "cjinit" }
attributes #1 = { "leaf-function" }
!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"funcmap"}
