; RUN: echo cj-wasm-return-bases-v1 > %t.in
; RUN: echo supplied >> %t.in
; RUN: echo weakSupplied >> %t.in
; RUN: echo varargsSupplied >> %t.in
; RUN: opt -passes=cj-runtime-lowering,verify -cj-wasm-root-version=1 -cj-wasm-export-return-bases=%t.out -cj-wasm-import-return-bases=%t.in -S %s -o %t.ll
; RUN: FileCheck %s --check-prefix=FACT --match-full-lines --input-file=%t.out
; RUN: FileCheck %s --check-prefix=IMPORT --input-file=%t.ll
; RUN: opt -passes=cj-runtime-lowering,verify -cj-wasm-root-version=1 -S %s -o - | FileCheck %s --check-prefix=DEFAULT
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

; Only the direct, ordinary tail call becomes a root. The imported fact
; does not become a declaration attribute or an exported wrapper fact.
; IMPORT: declare i8 addrspace(1)* @supplied()
; IMPORT-LABEL: define i8 addrspace(1)* @uses()
; IMPORT: %kept = tail call i8 addrspace(1)* @supplied()
; IMPORT: store volatile i8 addrspace(1)* %kept,
; IMPORT: call void @cjw_root_frame_push
; IMPORT-NEXT: call void @allocate()
; IMPORT-NEXT: [[RELOAD:%[^ ]+]] = load volatile i8 addrspace(1)*
; IMPORT-NEXT: call void @cjw_root_frame_pop
; IMPORT-NEXT: call void @consume(i8 addrspace(1)* [[RELOAD]])
; IMPORT: ret i8 addrspace(1)* [[RELOAD]]
; DEFAULT-LABEL: define i8 addrspace(1)* @uses()
; DEFAULT-NEXT: %kept = tail call i8 addrspace(1)* @supplied()
; DEFAULT-NEXT: call void @allocate()
; DEFAULT-NEXT: call void @consume(i8 addrspace(1)* %kept)
; DEFAULT-NEXT: ret i8 addrspace(1)* %kept
define i8 addrspace(1)* @uses() {
  %kept = tail call i8 addrspace(1)* @supplied()
  call void @allocate()
  call void @consume(i8 addrspace(1)* %kept)
  ret i8 addrspace(1)* %kept
}

; IMPORT-LABEL: define void @ineligible()
; IMPORT-NOT: @cjw_root_frame_push
; IMPORT: call void @consume(i8 addrspace(1)* %varargs)
; IMPORT-NEXT: ret void
define void @ineligible() {
  %weak = call i8 addrspace(1)* @weakSupplied()
  %varargs = call i8 addrspace(1)* (...) @varargsSupplied()
  call void @allocate()
  call void @consume(i8 addrspace(1)* %weak)
  call void @consume(i8 addrspace(1)* %varargs)
  ret void
}

; IMPORT-LABEL: define i8 addrspace(1)* @preserveMustTail()
; IMPORT-NEXT: %v = musttail call i8 addrspace(1)* @supplied()
; IMPORT-NEXT: ret i8 addrspace(1)* %v
define i8 addrspace(1)* @preserveMustTail() {
  %v = musttail call i8 addrspace(1)* @supplied()
  ret i8 addrspace(1)* %v
}

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"cj.wasm.root.version", i32 1}
!1 = !{}
