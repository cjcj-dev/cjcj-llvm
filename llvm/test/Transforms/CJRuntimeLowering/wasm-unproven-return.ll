; RUN: opt -passes=cj-runtime-lowering,verify -cj-wasm-root-version=1 -pass-remarks-missed='^cj-wasm-roots$' -S %s -o %t 2>&1 | FileCheck %s --check-prefix=REMARK --implicit-check-not='may carry an unproven call return'
; RUN: FileCheck %s --input-file=%t

target datalayout = "e-p:32:32-p1:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-wasi"

declare i8 addrspace(1)* @external()
declare "cj.wasm.base" i8 addrspace(1)* @known()
declare void @allocate()
declare void @leaf() "gc-leaf-function"
declare void @consume(i8 addrspace(1)*)

; The report works even in a function with zero proven owners. The result is
; live after allocate, but is unavailable at its own call and dead after consume.
; REMARK: value %kept may carry an unproven call return across allocate
; CHECK-LABEL: define void @kept()
; CHECK-NOT: @cjw_root_frame_push
; CHECK: %kept = call i8 addrspace(1)* @external()
; CHECK-NEXT: call void @leaf()
; CHECK-NEXT: call void @allocate()
; CHECK-NEXT: call void @consume(i8 addrspace(1)* %kept)
define void @kept() {
  %kept = call i8 addrspace(1)* @external()
  call void @leaf()
  call void @allocate()
  call void @consume(i8 addrspace(1)* %kept)
  ret void
}

; The unknown edge needs a report even when the existing root logic can
; preserve the known edge. The pointer surviving the second call is the PHI,
; whereas the pointer surviving the first call is the incoming projection.
; REMARK: value %interior may carry an unproven call return across allocate
; REMARK: value %merged may carry an unproven call return across allocate
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
; CHECK: call void @cjw_root_frame_push
; CHECK: call void @allocate()
; CHECK: [[RELOAD:%[^ ]+]] = load volatile i8 addrspace(1)*
; CHECK: call void @cjw_root_frame_pop
; CHECK: call void @consume(i8 addrspace(1)* [[RELOAD]])
define void @proven_return() {
  %base = call i8 addrspace(1)* @known()
  call void @allocate()
  call void @consume(i8 addrspace(1)* %base)
  ret void
}

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"cj.wasm.root.version", i32 1}
