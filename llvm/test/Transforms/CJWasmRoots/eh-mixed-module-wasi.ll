; In one wasm32-wasi module the Cangjie function still gets a catch_all funclet
; and CJ_MCC_WasmRethrow, while the foreign C++ function next to it does not.
; RUN: llc -O2 %s -o - | FileCheck %s
; RUN: llc -O0 %s -o - | FileCheck %s
target triple = "wasm32-unknown-wasi"

declare void @may_throw()
declare void @after(i8*)
declare i32 @__gxx_personality_v0(...)

define i32 @foreign() personality i32 (...)* @__gxx_personality_v0 {
entry:
  invoke void @may_throw() to label %ok unwind label %catch
ok:
  ret i32 0
catch:
  %lp = landingpad {i8*, i32} cleanup
  %selector = extractvalue {i8*, i32} %lp, 1
  ret i32 %selector
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

; CHECK-LABEL: foreign:
; CHECK-NOT: catch_all
; CHECK-NOT: CJ_MCC_WasmRethrow
; CHECK-LABEL: g:
; CHECK: try
; CHECK: call may_throw
; CHECK: catch_all
; CHECK: call after
; CHECK: call CJ_MCC_WasmRethrow
