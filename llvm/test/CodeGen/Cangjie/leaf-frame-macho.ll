; REQUIRES: x86-registered-target, aarch64-registered-target
; RUN: llc --cangjie-pipeline -mtriple=x86_64-apple-macosx15.0 %s -o - | FileCheck %s --check-prefixes=X86,MAP
; RUN: llc --cangjie-pipeline -mtriple=arm64-apple-macosx15.0 %s -o - | FileCheck %s --check-prefixes=ARM,MAP
;
; The real frame prologue must store the descriptor, even on legacy leaf IR.
; X86-LABEL: _leaf_frame:
; X86: leaq .Lmethod_desc.leafframe._leaf_frame(%rip), %r10
; X86-NEXT: pushq %r10
; ARM-LABEL: _leaf_frame:
; ARM: adrp x10, .Lmethod_desc.leafframe._leaf_frame@PAGE
; ARM-NEXT: add x10, x10, .Lmethod_desc.leafframe._leaf_frame@PAGEOFF
; MAP: __cjfuncmap
; MAP: .quad .Lmethod_desc.leafframe._leaf_frame
; MAP-LABEL: .Lmethod_desc.leafframe._leaf_frame:
; MAP-NEXT: .long .Lstack_map._leaf_frame-.Lmethod_desc.leafframe._leaf_frame

define void @leaf_frame() "leaf-function" gc "cangjie" {
  %token = call cangjiegccc token (...) @llvm.cj.gc.statepoint(i64 5, i32 0, void ()* @CJ_MCC_StackCheck, i32 0, i32 0)
  ret void
}
declare void @CJ_MCC_StackCheck()
declare token @llvm.cj.gc.statepoint(...)
!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"leafframe"}
