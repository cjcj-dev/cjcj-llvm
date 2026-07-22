; RUN: llc -O0 --cangjie-pipeline -mtriple=arm64-apple-darwin < %s | FileCheck %s --check-prefix=DARWIN
; RUN: llc -O0 --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu < %s | FileCheck %s --check-prefix=ELF

define void @stack_check() #0 gc "cangjie" {
entry:
  %token = call cangjiegccc token (...) @llvm.cj.gc.statepoint(i64 5, i32 0, void ()* @CJ_MCC_StackCheck, i32 0, i32 0)
  %slot = alloca i64, align 8
  store volatile i64 0, i64* %slot, align 8
  ret void
}

declare void @CJ_MCC_StackCheck()
declare token @llvm.cj.gc.statepoint(...)

attributes #0 = { "leaf-function" }

; DARWIN: bl _CJ_MCC_StackGrowStub
; DARWIN-NOT: bl CJ_MCC_StackGrowStub
; ELF: bl CJ_MCC_StackGrowStub
; ELF-NOT: bl _CJ_MCC_StackGrowStub
