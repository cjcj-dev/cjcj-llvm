; REQUIRES: asserts
; RUN: not --crash opt < %s -passes=cj-rewrite-statepoint -debug-only=safepoint-ir-verifier -S 2>&1 | FileCheck %s

; Looking through freeze must not hide a memory base the verifier cannot
; classify: a pointer produced by extractelement is still rejected, both bare
; and under freeze.

declare void @g() #0 gc "cangjie"
declare void @use_ptr(i8*) #0

define void @frozen_invalid_base(<2 x i8*> %v) #0 gc "cangjie" {
entry:
  %e = extractelement <2 x i8*> %v, i32 0
  %e.fr = freeze i8* %e
  call void @g()
  call void @use_ptr(i8* %e.fr)
  ret void
}

; CHECK: findMemoryBasePointer: look through   %e.fr = freeze i8* %e
; CHECK: findMemoryBasePointer: unexpected memory base   %e = extractelement <2 x i8*> %v, i32 0
; CHECK: SafepointIRVerifier.cpp:{{[0-9]+}}: {{.*}}findMemoryBasePointer{{.*}}Assertion

attributes #0 = { "record_mut" }
