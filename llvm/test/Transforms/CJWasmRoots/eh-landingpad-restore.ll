; Cangjie wasm32-wasi exception handling (M1).
; cj-wasm-roots resets __cj_root_top at every landingpad (I-FRAME under unwind),
; and llc lowers the landingpad to a catch_all funclet instead of dropping it
; with LowerInvoke (the 1eb33efe behaviour: no try/catch_all in the output).
; RUN: opt -passes=cj-wasm-roots,verify -S %s | FileCheck %s
; RUN: opt -passes=cj-wasm-roots %s -o %t.bc
; RUN: llc -O2 %t.bc -o - | FileCheck %s --check-prefix=WASM
; RUN: llc -O0 %t.bc -o - | FileCheck %s --check-prefix=WASM
target datalayout = "e-m:e-p:32:32-p1:32:32-i64:64-n32:64-S128-ni:1"
target triple = "wasm32-unknown-wasi"

declare void @may_throw()
declare i8* @CJ_MCC_GetExceptionWrapper()
declare void @after(i8*)

define void @f() gc "cangjie" personality i32 (...)* @"__cj_personality_v0$" {
entry:
  invoke void @may_throw() to label %ok unwind label %lpad
ok:
  ret void
lpad:
  %lp = landingpad token
          catch i8* null
  %w = call i8* @CJ_MCC_GetExceptionWrapper()
  call void @after(i8* %w)
  ret void
}

define void @g() gc "cangjie" personality i32 (...)* @"__cj_personality_v0$" {
entry:
  invoke void @may_throw() to label %ok unwind label %cleanup
ok:
  ret void
cleanup:
  %lp = landingpad token
          cleanup
  call void @after(i8* null)
  resume token %lp
}

define private i32 @"__cj_personality_v0$"(...) {
  ret i32 0
}

; CHECK-LABEL: define void @f(
; CHECK: lpad:
; CHECK-NEXT: %lp = landingpad token
; CHECK-NEXT: catch i8* null
; CHECK-NEXT: store i8* %wasm.root.{{entry|own}}, i8** @__cj_root_top
; CHECK-NEXT: call i8* @CJ_MCC_GetExceptionWrapper()
; CHECK-LABEL: define void @g(
; CHECK: cleanup:
; CHECK-NEXT: %lp = landingpad token
; CHECK-NEXT: cleanup
; CHECK-NEXT: store i8* %wasm.root.{{entry|own}}, i8** @__cj_root_top

; WASM-LABEL: f:
; WASM: try
; WASM: call may_throw
; WASM: catch_all
; WASM: __cj_root_top
; WASM: call CJ_MCC_GetExceptionWrapper
; WASM-LABEL: g:
; WASM: try
; WASM: call may_throw
; WASM: catch_all
; WASM: __cj_root_top
; WASM: call after
; WASM: call CJ_MCC_WasmRethrow
