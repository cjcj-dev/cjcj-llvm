; RUN: opt -passes=cj-runtime-lowering,verify -cj-wasm-root-version=1 -S %s | FileCheck %s
; RUN: sed -e 's/^; DYN://' %s | opt -passes=cj-runtime-lowering,verify -cj-wasm-root-version=1 -pass-remarks-missed='^cj-wasm-roots$' -S -o %t.ll 2> %t.remarks
; RUN: FileCheck %s --check-prefix=INCOMPLETE --input-file=%t.ll
; RUN: FileCheck %s --check-prefix=REMARK --input-file=%t.remarks
target datalayout = "e-p:32:32-p1:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-wasi"

declare void @collect()
declare void @use(i8 addrspace(1)*)
declare void @fill(i8* sret(i8))
declare { i8 addrspace(1)*, i64 } @pair()
declare i32 @__gxx_personality_v0(...)

; CHECK: @llvm.global_ctors = appending global [1 x { i32, void ()*, i8* }] [{ i32, void ()*, i8* } { i32 0, void ()* @.cj.wasm.roots_record, i8* null }]

; An invoke is a site; its frame is popped on the normal edge.
; CHECK-LABEL: define void @invoke_site(
; CHECK: store volatile i8 addrspace(1)* %p,
; CHECK: store volatile i32 -2147483647,
; CHECK-NEXT: call void @cjw_root_frame_push_complete(
; CHECK-NEXT: invoke void @collect()
; CHECK-NEXT: to label %ok unwind label %lp
; CHECK: ok:
; CHECK-NEXT: call void @cjw_root_frame_pop_complete(
define void @invoke_site(i8 addrspace(1)* %p) personality i32 (...)* @__gxx_personality_v0 {
entry:
  invoke void @collect() to label %ok unwind label %lp
ok:
  call void @use(i8 addrspace(1)* %p)
  ret void
lp:
  %l = landingpad { i8*, i32 } cleanup
  resume { i8*, i32 } %l
}

; A first-class aggregate publishes each managed leaf.
; CHECK-LABEL: define i64 @aggregate_leaf(
; CHECK: %v = call { i8 addrspace(1)*, i64 } @pair()
; CHECK: [[LEAF:%[^ ]+]] = extractvalue { i8 addrspace(1)*, i64 } %v, 0
; CHECK: store volatile i8 addrspace(1)* [[LEAF]],
; CHECK: call void @cjw_root_frame_push_complete(
; CHECK-NEXT: call void @collect()
define i64 @aggregate_leaf() {
  %v = call { i8 addrspace(1)*, i64 } @pair()
  call void @collect()
  %r = extractvalue { i8 addrspace(1)*, i64 } %v, 0
  call void @use(i8 addrspace(1)* %r)
  %n = extractvalue { i8 addrspace(1)*, i64 } %v, 1
  ret i64 %n
}

; Stack memory a callee may store a reference into is published in place, as
; zeroed whole words; its alignment is raised to the word size.
; CHECK-LABEL: define void @stack_range(
; CHECK: %buf = alloca [3 x i32], align 4
; CHECK: %wasm.root.ranges = alloca { i32, [1 x { i8*, i32 }] }
; CHECK: call void @llvm.memset.{{[^(]+}}(i8* align 4 {{%[^ ]+}}, i8 0, i{{32|64}} 12, i1 false)
; CHECK: store i32 3,
; CHECK: call void @cjw_root_frame_push_complete(
; CHECK-NEXT: call void @fill(i8* sret(i8) %raw)
; CHECK-NEXT: call void @cjw_root_frame_pop_complete(
define void @stack_range() {
  %buf = alloca [3 x i32], align 1
  %raw = bitcast [3 x i32]* %buf to i8*
  call void @fill(i8* sret(i8) %raw)
  call void @collect()
  ret void
}

; A slot used only as one non-pointer scalar holds no reference.
; CHECK-LABEL: define i64 @scalar_slot(
; CHECK-NOT: wasm.root.ranges
; CHECK: store volatile i8 addrspace(1)* %p,
; CHECK: call void @collect()
define i64 @scalar_slot(i8 addrspace(1)* %p) {
  %s = alloca i64
  store i64 1, i64* %s
  call void @collect()
  %v = load i64, i64* %s
  call void @use(i8 addrspace(1)* %p)
  ret i64 %v
}

; A derived pointer is published as is and used unchanged after the call:
; the non-moving collector marks the object containing it.
; CHECK-LABEL: define i8 @interior(
; CHECK: %f = getelementptr i8, i8 addrspace(1)* %o, i32 12
; CHECK: store volatile i8 addrspace(1)* %f,
; CHECK: call void @collect()
; CHECK-NEXT: call void @cjw_root_frame_pop_complete(
; CHECK-NEXT: %b = load i8, i8 addrspace(1)* %f
define i8 @interior(i8 addrspace(1)* %o) {
  %f = getelementptr i8, i8 addrspace(1)* %o, i32 12
  call void @collect()
  %b = load i8, i8 addrspace(1)* %f
  ret i8 %b
}

; CHECK: define internal void @.cj.wasm.roots_record()
; CHECK: call void @cjw_roots_module_complete(i8* null)

; A dynamic alloca is outside the contract: the module reports incomplete.
; DYN:define void @dynamic(i32 %n) {
; DYN:  %d = alloca i8 addrspace(1)*, i32 %n
; DYN:  call void @collect()
; DYN:  ret void
; DYN:}
; INCOMPLETE-NOT: @cjw_roots_module_complete
; INCOMPLETE: call void @cjw_roots_module_incomplete(i8* null)
; REMARK: wasm roots incomplete: dynamic alloca that may hold references

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"cj.wasm.root.version", i32 1}
