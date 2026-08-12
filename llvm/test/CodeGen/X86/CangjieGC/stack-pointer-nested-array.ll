; RUN: llc --cangjie-pipeline -O0 -mtriple=x86_64-unknown-linux-gnu \
; RUN:   -stop-after=cangjie-stack-pointer-inserter -o - < %s | FileCheck %s

declare token @llvm.cj.gc.statepoint(...)
declare void @safepoint()

; CHECK-LABEL: name: nested_array_stack_pointer
; CHECK: - { id: [[SLOT:[0-9]+]], name: nested,
; CHECK: STATEPOINT {{.*}}%stack.[[SLOT]].nested, 0
define i8* @nested_array_stack_pointer(i8* %stack_pointer) gc "cangjie" {
entry:
  %nested = alloca [2 x [2 x i8*]], align 8
  %first = getelementptr inbounds [2 x [2 x i8*]], [2 x [2 x i8*]]* %nested, i64 0, i64 0, i64 0
  store volatile i8* %stack_pointer, i8** %first, align 8
  %statepoint = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, void ()* @safepoint, i32 0, i32 0)
  %result = load volatile i8*, i8** %first, align 8
  ret i8* %result
}
