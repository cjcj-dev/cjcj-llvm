; RUN: split-file %s %t
; RUN: llc --cangjie-pipeline %t/plain.ll -o - | FileCheck %s --check-prefix=TOKEN
; RUN: llc --cangjie-pipeline %t/ibt.ll -o - | FileCheck %s --check-prefixes=IBT,TOKEN
; RUN: llc --cangjie-pipeline -mtriple=x86_64-apple-macosx %t/plain.ll -o - | FileCheck %s --check-prefix=MACHO
;
; The entry expression, not the position after a prologue CALL, creates the
; existing entry+9 slot token. PUSH/LEA/XCHG preserves flags and restores the
; temporary register. Real linked/GDB token observations belong to A2's
; producer/consumer acceptance; these checks only cover emitted instructions.
; IBT-LABEL: qualified_entry:
; IBT: endbr64
; TOKEN: pushq %r10
; TOKEN-NEXT: leaq {{.*}}+9(%rip), %r10
; TOKEN-NEXT: xchgq %r10, (%rsp)
; TOKEN-NOT: callq .LStorePC
; TOKEN: callq callee
; MACHO-LABEL: _qualified_entry:
; MACHO: pushq %r10
; MACHO-NEXT: leaq {{.*}}+9(%rip), %r10
; MACHO-NEXT: xchgq %r10, (%rsp)
; MACHO-NEXT: pushq %r10
; MACHO-NEXT: leaq {{.*}}method_desc{{.*}}(%rip), %r10
; MACHO-NEXT: xchgq %r10, (%rsp)
;
;--- plain.ll
 target triple = "x86_64-unknown-linux-gnu"
 define void @qualified_entry() gc "cangjie" {
 entry:
   call void @callee()
   ret void
 }
 declare void @callee()
 !llvm.module.flags = !{!0}
 !0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_entry_token"}

;--- ibt.ll
 target triple = "x86_64-unknown-linux-gnu"
 define void @qualified_entry() gc "cangjie" {
 entry:
   call void @callee()
   ret void
 }
 declare void @callee()
 !llvm.module.flags = !{!0, !1}
 !0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_entry_token"}
 !1 = !{i32 7, !"cf-protection-branch", i32 1}
