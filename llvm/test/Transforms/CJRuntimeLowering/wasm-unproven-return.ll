; RUN: opt -passes=cj-runtime-lowering,verify -cj-wasm-root-version=1 -pass-remarks-missed='^cj-wasm-roots$' -S %s -o %t 2>&1 | count 0
; RUN: FileCheck %s --input-file=%t

; Under the complete root contract an unproven call return is published like
; any other managed value: no proof and no remark are needed.
; CHECK: @llvm.global_ctors = appending global [1 x { i32, void ()*, i8* }] [{ i32, void ()*, i8* } { i32 0, void ()* @.cj.wasm.roots_record, i8* null }]

target datalayout = "e-p:32:32-p1:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-wasi"

declare i8 addrspace(1)* @external()
declare "cj.wasm.base" i8 addrspace(1)* @known()
declare void @allocate()
declare void @leaf() "gc-leaf-function"
declare void @consume(i8 addrspace(1)*)

; CHECK-LABEL: define void @kept()
; CHECK: %kept = call i8 addrspace(1)* @external()
; CHECK-NEXT: call void @leaf()
; CHECK: store volatile i8 addrspace(1)* %kept,
; CHECK: store volatile i32 -2147483647,
; CHECK-NEXT: call void @cjw_root_frame_push_complete(
; CHECK-NEXT: call void @allocate()
; CHECK-NEXT: call void @cjw_root_frame_pop_complete(
; CHECK: store volatile i8 addrspace(1)* %kept,
; CHECK: call void @cjw_root_frame_push_complete(
; CHECK-NEXT: call void @consume(i8 addrspace(1)* %kept)
; CHECK-NEXT: call void @cjw_root_frame_pop_complete(
define void @kept() {
  %kept = call i8 addrspace(1)* @external()
  call void @leaf()
  call void @allocate()
  call void @consume(i8 addrspace(1)* %kept)
  ret void
}

; CHECK-LABEL: define i8 addrspace(1)* @mixed_return(
; CHECK: %interior = getelementptr i8, i8 addrspace(1)* %retval, i32 8
; CHECK: store volatile i8 addrspace(1)* %interior,
; CHECK: call void @cjw_root_frame_push_complete(
; CHECK-NEXT: call void @allocate()
; CHECK: %merged = phi i8 addrspace(1)* [ %interior, %unknown ], [ %base, %proven ]
; CHECK: store volatile i8 addrspace(1)* %merged,
; CHECK: call void @cjw_root_frame_push_complete(
; CHECK-NEXT: call void @allocate()
; CHECK-NEXT: call void @cjw_root_frame_pop_complete(
; CHECK-NEXT: ret i8 addrspace(1)* %merged
define i8 addrspace(1)* @mixed_return(i1 %choose) {
entry:
  br i1 %choose, label %unknown, label %proven
unknown:
  %retval = call i8 addrspace(1)* @external()
  %interior = getelementptr i8, i8 addrspace(1)* %retval, i32 8
  call void @allocate()
  br label %join
proven:
  %base = call i8 addrspace(1)* @known()
  br label %join
join:
  %merged = phi i8 addrspace(1)* [ %interior, %unknown ], [ %base, %proven ]
  call void @allocate()
  ret i8 addrspace(1)* %merged
}

; CHECK-LABEL: define void @proven_return()
; CHECK: %base = call i8 addrspace(1)* @known()
; CHECK: store volatile i8 addrspace(1)* %base,
; CHECK: call void @cjw_root_frame_push_complete(
; CHECK-NEXT: call void @allocate()
; CHECK-NEXT: call void @cjw_root_frame_pop_complete(
; CHECK: call void @consume(i8 addrspace(1)* %base)
; CHECK: define internal void @.cj.wasm.roots_record()
; CHECK: call void @cjw_roots_module_complete(i8* null)
define void @proven_return() {
  %base = call i8 addrspace(1)* @known()
  call void @allocate()
  call void @consume(i8 addrspace(1)* %base)
  ret void
}

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"cj.wasm.root.version", i32 1}
