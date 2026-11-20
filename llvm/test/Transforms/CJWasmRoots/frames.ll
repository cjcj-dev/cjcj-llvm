; RUN: opt -passes=cj-wasm-roots,verify -S %s | FileCheck %s
; RUN: opt -passes=cj-wasm-roots,cj-wasm-roots,verify -S %s | FileCheck %s --check-prefix=ONCE
; RUN: opt -passes='default<O2>' -cangjie-pipeline -S %s | FileCheck %s --check-prefix=PIPE
; RUN: sed -e 's/^; ERR-DYN://' %s > %t.dyn.ll
; RUN: not opt -passes=cj-wasm-roots -disable-output %t.dyn.ll 2>&1 | FileCheck %s --check-prefix=DYN
; RUN: sed -e 's/^; ERR-TAIL://' %s > %t.tail.ll
; RUN: not opt -passes=cj-wasm-roots -disable-output %t.tail.ll 2>&1 | FileCheck %s --check-prefix=TAIL
; RUN: sed -e 's/^; ERR-PHI://' %s > %t.phi.ll
; RUN: not opt -passes=cj-wasm-roots -disable-output %t.phi.ll 2>&1 | FileCheck %s --check-prefix=PHI
target datalayout = "e-m:e-p:32:32-p1:32:32-i64:64-n32:64-S128-ni:1"
target triple = "wasm32-unknown-wasi"

declare void @collect()
declare void @use(i8 addrspace(1)*)
declare void @useInt(i32)
declare i8 addrspace(1)* @make()
declare i32 @__gxx_personality_v0(...)
declare void @llvm.memset.p0i8.i32(i8*, i8, i32, i1)

; Entry links the frame, every may-collect call writes slots and nslots, every
; return unlinks. Slot stores are ordinary stores; no runtime push/pop calls.
; CHECK-LABEL: define void @live_across(i8 addrspace(1)* %p)
; CHECK: %wasm.root.frame = alloca { i8*, i8*, i32, [1 x i8 addrspace(1)*] }
; CHECK: %wasm.root.prev = load i8*, i8** @__cj_root_top
; CHECK: store i8* %wasm.root.prev, i8**
; CHECK: store i32 0,
; CHECK: store i8* {{.*}}, i8** @__cj_root_top
; CHECK: store i8 addrspace(1)* %p, i8 addrspace(1)**
; CHECK: store i32 1,
; CHECK-NEXT: call void @collect()
; CHECK: store i8* %wasm.root.prev, i8** @__cj_root_top
; CHECK-NEXT: ret void
; CHECK-NOT: cjw_push_frame
; CHECK-NOT: cjw_pop_frame
define void @live_across(i8 addrspace(1)* %p) {
  call void @collect()
  call void @use(i8 addrspace(1)* %p)
  ret void
}

; A value that is only a call argument is published at that call (I-CARG),
; and a dead value is not published at a later call (nslots = 0 still written).
; CHECK-LABEL: define void @arg_only(
; CHECK: store i8 addrspace(1)* %p, i8 addrspace(1)**
; CHECK: store i32 1,
; CHECK-NEXT: call void @use(i8 addrspace(1)* %p)
; CHECK: store i32 0,
; CHECK-NEXT: call void @collect()
define void @arg_only(i8 addrspace(1)* %p) {
  call void @use(i8 addrspace(1)* %p)
  call void @collect()
  ret void
}

; Rule 4: a derived GEP live across the call publishes its root, not itself.
; CHECK-LABEL: define void @derived(
; CHECK: store i8 addrspace(1)* %p, i8 addrspace(1)**
; CHECK: store i32 1,
; CHECK-NEXT: call void @collect()
define void @derived(i8 addrspace(1)* %p) {
  %q = getelementptr inbounds i8, i8 addrspace(1)* %p, i32 16
  call void @collect()
  call void @use(i8 addrspace(1)* %q)
  ret void
}

; Rule 2: a reference that crosses the call only as an integer keeps its
; source alive.
; CHECK-LABEL: define void @as_integer(
; CHECK: store i8 addrspace(1)* %p, i8 addrspace(1)**
; CHECK: store i32 1,
; CHECK-NEXT: call void @collect()
define void @as_integer(i8 addrspace(1)* %p) {
  %i = ptrtoint i8 addrspace(1)* %p to i32
  call void @collect()
  call void @useInt(i32 %i)
  ret void
}

; A call result is not published at its own call; invoke is a site whose
; unwind edge needs no code.
; CHECK-LABEL: define void @invoke_site(
; CHECK: store i8* {{.*}}, i8** @__cj_root_top
; CHECK: store i32 0,
; CHECK-NEXT: %r = invoke i8 addrspace(1)* @make()
; CHECK: store i8 addrspace(1)* %r, i8 addrspace(1)**
; CHECK: store i32 1,
; CHECK-NEXT: call void @collect()
define void @invoke_site() personality i32 (...)* @__gxx_personality_v0 {
entry:
  %r = invoke i8 addrspace(1)* @make() to label %ok unwind label %lp
ok:
  call void @collect()
  call void @use(i8 addrspace(1)* %r)
  ret void
lp:
  %l = landingpad { i8*, i32 } cleanup
  resume { i8*, i32 } %l
}

; LLVM intrinsics other than llvm.cj.* are not sites; tail markers are cleared.
; CHECK-LABEL: define void @intrinsic_not_site(
; CHECK-NOT: wasm.root.frame
; CHECK: ret void
define void @intrinsic_not_site(i8* %d, i8 addrspace(1)* %p) {
  call void @llvm.memset.p0i8.i32(i8* %d, i8 0, i32 8, i1 false)
  ret void
}

; A slot that may hold a reference is a range: cleared at entry and named in
; the frame's range table.
; CHECK-LABEL: define void @range(
; CHECK: %slot = alloca i8 addrspace(1)*
; CHECK: %wasm.root.ranges = alloca { i32, [1 x { i8*, i32 }] }
; CHECK: store i32 1, i32*
; CHECK: call void @llvm.memset.p0i8.{{i32|i64}}(i8* {{.*}}, i8 0, {{i32|i64}} 4,
; CHECK: store i32 4, i32*
; CHECK: call void @collect()
define void @range(i8 addrspace(1)* %p) {
  %slot = alloca i8 addrspace(1)*
  store i8 addrspace(1)* %p, i8 addrspace(1)** %slot
  call void @collect()
  %v = load i8 addrspace(1)*, i8 addrspace(1)** %slot
  call void @use(i8 addrspace(1)* %v)
  ret void
}

; A tail call in a frame function is no longer a tail call.
; CHECK-LABEL: define void @tail_cleared(
; CHECK-NOT: tail call
; CHECK: ret void
define void @tail_cleared(i8 addrspace(1)* %p) {
  call void @collect()
  tail call void @use(i8 addrspace(1)* %p)
  ret void
}

; ONCE-COUNT-1: %wasm.root.frame = alloca { i8*, i8*, i32, [1 x i8 addrspace(1)*] }
; ONCE-NOT: %wasm.root.frame1
; PIPE: define void @live_across(
; PIPE: @__cj_root_top

; ERR-DYN:define void @dyn(i32 %n) {
; ERR-DYN:  %a = alloca i8 addrspace(1)*, i32 %n
; ERR-DYN:  call void @collect()
; ERR-DYN:  ret void
; ERR-DYN:}
; DYN: unsupported WASI root publication in dyn: dynamic alloca that may hold references

; ERR-TAIL:define void @mt(i8 addrspace(1)* %p) {
; ERR-TAIL:  call void @collect()
; ERR-TAIL:  musttail call void @use(i8 addrspace(1)* %p)
; ERR-TAIL:  ret void
; ERR-TAIL:}
; TAIL: unsupported WASI root publication in mt: musttail

; ERR-PHI:define void @phi(i1 %c, i8 addrspace(1)* %a, i8 addrspace(1)* %b) {
; ERR-PHI:entry:
; ERR-PHI:  br i1 %c, label %l, label %r
; ERR-PHI:l:
; ERR-PHI:  %x = getelementptr i8, i8 addrspace(1)* %a, i32 100000
; ERR-PHI:  br label %j
; ERR-PHI:r:
; ERR-PHI:  br label %j
; ERR-PHI:j:
; ERR-PHI:  %m = phi i8 addrspace(1)* [ %x, %l ], [ %b, %r ]
; ERR-PHI:  call void @collect()
; ERR-PHI:  call void @use(i8 addrspace(1)* %m)
; ERR-PHI:  ret void
; ERR-PHI:}
; PHI: unsupported WASI root publication in phi: merged derived reference m
