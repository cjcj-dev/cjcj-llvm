; RUN: opt -passes=cj-runtime-lowering,verify -pass-remarks-missed='^cj-wasm-roots$' -S %s -o %t 2>&1 | count 0
; RUN: FileCheck %s --input-file=%t

; Under the complete root contract an unproven call return is published like
; any other managed value: no proof and no remark are needed.

target datalayout = "e-p:32:32-p1:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-wasi"

declare i8 addrspace(1)* @external()
declare "cj.wasm.base" i8 addrspace(1)* @known()
declare void @allocate()
declare void @leaf() "gc-leaf-function"
declare void @consume(i8 addrspace(1)*)

; CHECK-LABEL: define void @kept()
; CHECK: %kept = call i8 addrspace(1)* @external()
; CHECK: store volatile i8 addrspace(1)* %kept,
; CHECK: store volatile i32 1,
; CHECK-NEXT: call void @cjw_push_frame(
; CHECK-NEXT: call void @leaf()
; CHECK-NEXT: call void @cjw_pop_frame(
; CHECK: store volatile i8 addrspace(1)* %kept,
; CHECK: store volatile i32 1,
; CHECK-NEXT: call void @cjw_push_frame(
; CHECK-NEXT: call void @allocate()
; CHECK-NEXT: call void @cjw_pop_frame(
; CHECK: store volatile i8 addrspace(1)* %kept,
; CHECK: call void @cjw_push_frame(
; CHECK-NEXT: call void @consume(i8 addrspace(1)* %kept)
; CHECK-NEXT: call void @cjw_pop_frame(
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
; CHECK: call void @cjw_push_frame(
; CHECK-NEXT: call void @allocate()
; CHECK: %merged = phi i8 addrspace(1)* [ %interior, %unknown ], [ %base, %proven ]
; CHECK: store volatile i8 addrspace(1)* %merged,
; CHECK: call void @cjw_push_frame(
; CHECK-NEXT: call void @allocate()
; CHECK-NEXT: call void @cjw_pop_frame(
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
; CHECK: call void @cjw_push_frame(
; CHECK-NEXT: call void @allocate()
; CHECK-NEXT: call void @cjw_pop_frame(
; CHECK: call void @consume(i8 addrspace(1)* %base)
define void @proven_return() {
  %base = call i8 addrspace(1)* @known()
  call void @allocate()
  call void @consume(i8 addrspace(1)* %base)
  ret void
}
