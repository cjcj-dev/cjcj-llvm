; REQUIRES: asserts
; RUN: opt < %s -passes=cj-rewrite-statepoint -S 2>&1 | FileCheck %s
; RUN: opt < %s -cj-rewrite-statepoint -S 2>&1 | FileCheck %s
; RUN: opt < %s -passes=cj-rewrite-statepoint -debug-only=safepoint-ir-verifier -S 2>&1 | FileCheck %s --check-prefix=TRACE

; CJSpecificOpt freezes the inputs of the fused MTable lookup when it cannot
; prove they are neither undef nor poison.  The memory base of freeze(P) is the
; memory base of P, so a frozen stack pointer must still resolve to its alloca
; and keep the stack object struct-live across the earlier safepoint.

%LocalBox = type { i8 addrspace(1)* }

declare void @g() #0 gc "cangjie"
declare void @use_box(i8*) #0
declare i8* @CJ_MCC_GetMTableAndOuterTI(i8*, i8*, i64, i8**) #1

define void @frozen_stack_arg(i8 addrspace(1)* %heap) #0 gc "cangjie" {
entry:
  %box = alloca %LocalBox, align 8
  %box.value = getelementptr inbounds %LocalBox, %LocalBox* %box, i64 0, i32 0
  store i8 addrspace(1)* %heap, i8 addrspace(1)** %box.value, align 8
  %box.i8 = bitcast %LocalBox* %box to i8*
  %box.fr = freeze i8* %box.i8
  call void @g()
  call void @use_box(i8* %box.fr)
  ret void
}

; CHECK-LABEL: define void @frozen_stack_arg
; CHECK: %box.fr = freeze i8* %box.i8
; CHECK: call token (...) @llvm.cj.gc.statepoint({{.*}}@g{{.*}}"struct-live"({{.*}}%LocalBox* %box{{.*}})
; CHECK: call token (...) @llvm.cj.gc.statepoint({{.*}}@use_box, i32 1, i32 0, i8* %box.fr) [ "struct-live"(%LocalBox* %box) ]

; The fused lookup shape: both inputs frozen, the outer-TI slot on the stack.
define i8* @fused_mtable_inputs(i8* %ti, i8* %outer) #0 gc "cangjie" {
entry:
  %mtable.outer.ti = alloca i8*, align 8
  call void @g()
  %ti.fr = freeze i8* %ti
  %outer.fr = freeze i8* %outer
  %pair = call i8* @CJ_MCC_GetMTableAndOuterTI(i8* %ti.fr, i8* %outer.fr, i64 3, i8** %mtable.outer.ti)
  ret i8* %pair
}

; CHECK-LABEL: define i8* @fused_mtable_inputs
; CHECK: %ti.fr = freeze i8* %ti
; CHECK: %outer.fr = freeze i8* %outer
; CHECK: call i8* @CJ_MCC_GetMTableAndOuterTI(i8* %ti.fr, i8* %outer.fr, i64 3, i8** %mtable.outer.ti)

; TRACE: findMemoryBasePointer: look through   %box.fr = freeze i8* %box.i8
; TRACE: findMemoryBasePointer: look through   %ti.fr = freeze i8* %ti
; TRACE-NOT: unexpected memory base

attributes #0 = { "record_mut" }
attributes #1 = { nounwind "cj-runtime" "gc-leaf-function" }
