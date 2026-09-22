; RUN: opt -S -passes=always-inline < %s | FileCheck %s
; Inlining clones the product StoreInst. Its semantic decorator must survive.
define internal void @helper(i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p) alwaysinline {
  store cj_strength(2) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p
  ret void
}
define void @caller(i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p) {
; CHECK-LABEL: define void @caller(
; CHECK-NOT: call
; CHECK: store cj_strength(2) i8 addrspace(1)* %v,
  call void @helper(i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p)
  ret void
}
