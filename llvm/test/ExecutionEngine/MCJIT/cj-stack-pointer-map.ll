; REQUIRES: native, x86_64-linux
; RUN: rm -rf %t.O0-false
; RUN: %lli -jit-kind=mcjit -O0 -code-model=small -cj-stack-grow=false -enable-cache-manager -object-cache-dir=%t.O0-false %s
; RUN: %python %S/Inputs/check-cj-jit-stack-pointer-map.py %t.O0-false
; RUN: rm -rf %t.O0-true
; RUN: %lli -jit-kind=mcjit -O0 -code-model=small -cj-stack-grow=true -enable-cache-manager -object-cache-dir=%t.O0-true %s
; RUN: %python %S/Inputs/check-cj-jit-stack-pointer-map.py %t.O0-true
; RUN: rm -rf %t.O2-false
; RUN: %lli -jit-kind=mcjit -O2 -code-model=small -cj-stack-grow=false -enable-cache-manager -object-cache-dir=%t.O2-false %s
; RUN: %python %S/Inputs/check-cj-jit-stack-pointer-map.py %t.O2-false
; RUN: rm -rf %t.O2-true
; RUN: %lli -jit-kind=mcjit -O2 -code-model=small -cj-stack-grow=true -enable-cache-manager -object-cache-dir=%t.O2-true %s
; RUN: %python %S/Inputs/check-cj-jit-stack-pointer-map.py %t.O2-true
;
; Cangjie_OPT selects the Cangjie pipeline inside MCJIT::emitObject. Do not
; replace this real entry with llc -cangjie-JIT: that would miss the routing.
; The non-GC main lets the object be compiled and linked without a runtime.
; GC frame execution is outside this compiler metadata test.

%record = type { i64, i64 }

define void @sret_forward(%record* sret(%record) %out) gc "cangjie" {
entry:
  call void @fill(%record* sret(%record) %out)
  %field = getelementptr %record, %record* %out, i32 0, i32 1
  store volatile i64 7, i64* %field
  ret void
}

define void @fill(%record* sret(%record) %out) noinline gc "cangjie" {
  %field = getelementptr %record, %record* %out, i32 0, i32 0
  store volatile i64 5, i64* %field
  ret void
}

define i32 @main() {
  ret i32 0
}

; Link-time sentinels only: executing a GC function without a Cangjie thread
; would be invalid. Any accidental entry into these handlers must fail.
declare void @abort() noreturn
define void @CJ_MCC_HandleSafepoint() {
  call void @abort()
  unreachable
}
define void @CJ_MCC_HandleReturnSafepoint() {
  call void @abort()
  unreachable
}

!llvm.module.flags = !{!0}
!0 = !{i32 2, !"Cangjie_OPT", i32 0}
