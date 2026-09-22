; RUN: llvm-as < %s | llvm-dis | FileCheck %s
; RUN: opt -S -passes=mergefunc < %s | FileCheck %s
; A store decorator is semantic state, including in bitcode and function identity.
; Two real slot stores exceed MergeFunctions::canCreateThunkFor's tiny-function
; threshold; the comparison must affect the product transformation result.

define void @strong(i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p) {
; CHECK-LABEL: define void @strong(
; CHECK: store cj_strength(1) i8 addrspace(1)* %v,
  store cj_strength(1) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p
  %next = getelementptr i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %p, i64 1
  store cj_strength(1) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %next
  ret void
}
define void @weak(i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p) {
; CHECK-LABEL: define void @weak(
; CHECK: store cj_strength(2) i8 addrspace(1)* %v,
  store cj_strength(2) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p
  %next = getelementptr i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %p, i64 1
  store cj_strength(2) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %next
  ret void
}
define void @unknown(i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p) {
; CHECK-LABEL: define void @unknown(
; CHECK: store i8 addrspace(1)* %v,
  store i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p
  %next = getelementptr i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %p, i64 1
  store i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %next
  ret void
}
define void @atomic_weak(i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p) {
; CHECK-LABEL: define void @atomic_weak(
; CHECK: store atomic volatile cj_strength(2) i8 addrspace(1)* %v, {{.*}} release, align 8
  store atomic volatile cj_strength(2) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p release, align 8
  %next = getelementptr i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %p, i64 1
  store atomic volatile cj_strength(2) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %next release, align 8
  ret void
}
