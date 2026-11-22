; Cangjie wasm EH must only touch Cangjie functions on wasm32-wasi. A foreign
; C++ landingpad (__gxx_personality_v0, {i8*, i32}) keeps its selector, and no
; triple other than wasm32-wasi gets default wasm EH: no catch_all, no
; CJ_MCC_WasmRethrow on any of the five triples.
; RUN: llc -mtriple=wasm64-unknown-wasi -O2 %s -o - | FileCheck %s --check-prefix=NOCJ
; RUN: llc -mtriple=wasm32-unknown-wasi -O2 %s -o - | FileCheck %s --check-prefix=NOCJ
; RUN: llc -mtriple=wasm32-unknown-wasi -O0 %s -o - | FileCheck %s --check-prefix=NOCJ
; RUN: llc -mtriple=wasm32-unknown-unknown -O2 %s -o - | FileCheck %s --check-prefix=NOCJ
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O2 %s -o - | FileCheck %s --check-prefixes=NOCJ,ITANIUM
; RUN: llc -mtriple=aarch64-unknown-linux-gnu -O2 %s -o - | FileCheck %s --check-prefixes=NOCJ,ITANIUM
; RUN: llc -mtriple=wasm32-unknown-wasi -O2 -stop-after=wasm-cj-lower-landingpads %s -o - | FileCheck %s --check-prefix=IR

declare void @may_throw()
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

; NOCJ-NOT: catch_all
; NOCJ-NOT: CJ_MCC_WasmRethrow
; NOCJ-NOT: __gxx_wasm_personality_v0
; NOCJ-LABEL: foreign:
; NOCJ-NOT: catch_all
; NOCJ-NOT: CJ_MCC_WasmRethrow
; NOCJ-NOT: __gxx_wasm_personality_v0
; ITANIUM: .cfi_personality {{.*}}__gxx_personality_v0

; After the Cangjie landingpad lowering the foreign pad is unchanged.
; IR-LABEL: define i32 @foreign()
; IR-SAME: personality {{.*}}@__gxx_personality_v0
; IR-NOT: catchswitch
; IR-NOT: undef
; IR: %lp = landingpad { i8*, i32 }
; IR-NEXT: cleanup
; IR-NEXT: %selector = extractvalue { i8*, i32 } %lp, 1
; IR-NEXT: ret i32 %selector
