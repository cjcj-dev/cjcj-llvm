; RUN: echo cj-wasm-return-bases-v1 > %t.in
; RUN: echo supplied >> %t.in
; RUN: echo weakSupplied >> %t.in
; RUN: echo varargsSupplied >> %t.in
; RUN: opt -passes=cj-runtime-lowering,verify -cj-wasm-root-version=1 -cj-wasm-export-return-bases=%t.out -cj-wasm-import-return-bases=%t.in -S %s -o %t.ll
; RUN: FileCheck %s --check-prefix=FACT --match-full-lines --input-file=%t.out
; RUN: FileCheck %s --check-prefixes=ROOTS,IMPORT --input-file=%t.ll
; RUN: opt -passes=cj-runtime-lowering,verify -cj-wasm-root-version=1 -S %s -o - | FileCheck %s --check-prefix=ROOTS
; RUN: not opt -passes='default<O2>,verify' -cangjie-pipeline -cj-wasm-export-return-bases=%t.extra -disable-output %s 2>&1 | FileCheck %s --check-prefix=PIPELINE
; PIPELINE: wasm return bases require the default non-LTO Cangjie pipeline

target datalayout = "e-p:32:32-p1:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-wasi"

declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare i8 addrspace(1)* @supplied()
declare extern_weak i8 addrspace(1)* @weakSupplied()
declare i8 addrspace(1)* @varargsSupplied(...)
declare "cj.wasm.base" i8 addrspace(1)* @asserted()
declare i8 addrspace(1)* @unknownCtor(i8 addrspace(1)*)
declare void @allocate()
declare void @consume(i8 addrspace(1)*) "gc-leaf-function"

; The full file consists of the header and exactly the eligible symbols.
; FACT: cj-wasm-return-bases-v1
; FACT-NEXT: heap
; FACT-NEXT: nullable
; FACT-NEXT: localCtorFactory
; FACT-NOT: {{.}}

define i8 addrspace(1)* @heap(i8* %ti) {
  %base = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* %ti, i32 16), !TrustedSize !1
  ; The fact is taken before the return becomes a frame reload.
  call void @allocate()
  ret i8 addrspace(1)* %base
}

define i8 addrspace(1)* @nullable(i8* %ti, i1 %condition) {
  br i1 %condition, label %new, label %empty
new:
  %base = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* %ti, i32 16), !TrustedSize !1
  ret i8 addrspace(1)* %base
empty:
  ret i8 addrspace(1)* null
}

define internal i8 addrspace(1)* @identity(i8 addrspace(1)* %self) {
  ret i8 addrspace(1)* %self
}

define i8 addrspace(1)* @localCtorFactory(i8* %ti) {
  %base = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* %ti, i32 16), !TrustedSize !1
  %v = call i8 addrspace(1)* @identity(i8 addrspace(1)* %base), !cj.wasm.constructor_receiver !1
  ret i8 addrspace(1)* %v
}

define i8 addrspace(1)* @unknownCtorFactory(i8* %ti) {
  %base = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* %ti, i32 16), !TrustedSize !1
  %v = call i8 addrspace(1)* @unknownCtor(i8 addrspace(1)* %base), !cj.wasm.constructor_receiver !1
  ret i8 addrspace(1)* %v
}

define internal i8 addrspace(1)* @otherArgument(i8 addrspace(1)* %self, i8 addrspace(1)* %other) {
  ret i8 addrspace(1)* %other
}

define i8 addrspace(1)* @mixedReturn(i8* %ti, i1 %condition, i8 addrspace(1)* %other) {
  %base = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* %ti, i32 16), !TrustedSize !1
  br i1 %condition, label %heap, label %unproven
heap:
  ret i8 addrspace(1)* %base
unproven:
  %v = call i8 addrspace(1)* @otherArgument(i8 addrspace(1)* %base, i8 addrspace(1)* %other), !cj.wasm.constructor_receiver !1
  ret i8 addrspace(1)* %v
}

define i8 addrspace(1)* @interior(i8* %ti) {
  %base = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* %ti, i32 16), !TrustedSize !1
  %field = getelementptr i8, i8 addrspace(1)* %base, i32 1
  ret i8 addrspace(1)* %field
}

define i8 addrspace(1)* @callerStorage(i8* %storage) {
  %view = addrspacecast i8* %storage to i8 addrspace(1)*
  ret i8 addrspace(1)* %view
}

define i8 addrspace(1)* @parameter(i8 addrspace(1)* "cj.wasm.base" %p) {
  ret i8 addrspace(1)* %p
}

define i8 addrspace(1)* @assertedResult() {
  %p = call i8 addrspace(1)* @asserted()
  ret i8 addrspace(1)* %p
}

define weak i8 addrspace(1)* @weakNull() {
  ret i8 addrspace(1)* null
}

; Imported return-base facts stay records only: they do not become a
; declaration attribute or an exported wrapper fact, and rooting under the
; complete contract does not depend on them (imported and default outputs
; publish the same frames).
; IMPORT: declare i8 addrspace(1)* @supplied()
; ROOTS-LABEL: define i8 addrspace(1)* @uses()
; ROOTS: %kept = tail call i8 addrspace(1)* @supplied()
; ROOTS: store volatile i8 addrspace(1)* %kept,
; ROOTS: call void @cjw_root_frame_push_complete(
; ROOTS-NEXT: call void @allocate()
; ROOTS-NEXT: call void @cjw_root_frame_pop_complete(
; ROOTS-NEXT: call void @consume(i8 addrspace(1)* %kept)
; ROOTS-NEXT: ret i8 addrspace(1)* %kept
; ROOTS-LABEL: define void @receiverIdentity
; ROOTS: store volatile i8 addrspace(1)* %obj,
; ROOTS: call void @cjw_root_frame_push_complete(
; ROOTS-NEXT: %v = call i8 addrspace(1)* @outerCtor(i8 addrspace(1)* %obj)
; ROOTS-NEXT: call void @cjw_root_frame_pop_complete(
; ROOTS: store volatile i8 addrspace(1)* %obj,
; ROOTS: call void @cjw_root_frame_push_complete(
; ROOTS-NEXT: call void @allocate()
; ROOTS-NEXT: call void @cjw_root_frame_pop_complete(
; ROOTS-NEXT: call void @consume(i8 addrspace(1)* %obj)
; ROOTS-LABEL: define void @ineligible()
; ROOTS: store volatile i8 addrspace(1)* %weak,
; ROOTS: %varargs = call i8 addrspace(1)* (...) @varargsSupplied()
; ROOTS: store volatile i8 addrspace(1)* %weak,
; ROOTS: store volatile i8 addrspace(1)* %varargs,
; ROOTS: store volatile i32 -2147483646,
; ROOTS: call void @allocate()
; ROOTS-LABEL: define i8 addrspace(1)* @preserveMustTail()
; ROOTS-NEXT: %v = musttail call i8 addrspace(1)* @supplied()
; ROOTS-NEXT: ret i8 addrspace(1)* %v
define i8 addrspace(1)* @uses() {
  %kept = tail call i8 addrspace(1)* @supplied()
  call void @allocate()
  call void @consume(i8 addrspace(1)* %kept)
  ret i8 addrspace(1)* %kept
}

; A constructor identity also proves its raw i8 AS1 receiver is the heap
; object being initialized.  Keep the typed record-view case conservative;
; this test exercises only the class-constructor ABI shape.
define i8 addrspace(1)* @identityCtor(i8 addrspace(1)* %self) {
  ret i8 addrspace(1)* %self
}

define i8 addrspace(1)* @outerCtor(i8 addrspace(1)* %self) {
  %v = call i8 addrspace(1)* @identityCtor(i8 addrspace(1)* %self), !cj.wasm.constructor_receiver !1
  ret i8 addrspace(1)* %v
}

define void @receiverIdentity(i8 addrspace(1)* %obj) {
  %v = call i8 addrspace(1)* @outerCtor(i8 addrspace(1)* %obj), !cj.wasm.constructor_receiver !1
  call void @allocate()
  call void @consume(i8 addrspace(1)* %obj)
  ret void
}

define void @ineligible() {
  %weak = call i8 addrspace(1)* @weakSupplied()
  %varargs = call i8 addrspace(1)* (...) @varargsSupplied()
  call void @allocate()
  call void @consume(i8 addrspace(1)* %weak)
  call void @consume(i8 addrspace(1)* %varargs)
  ret void
}

define i8 addrspace(1)* @preserveMustTail() {
  %v = musttail call i8 addrspace(1)* @supplied()
  ret i8 addrspace(1)* %v
}

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"cj.wasm.root.version", i32 1}
!1 = !{}
