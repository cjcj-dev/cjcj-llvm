; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O0 -print-after=cj-barrier-lowering -print-module-scope -filter-print-funcs=plain_stack_store -o /dev/null < %s 2>&1 | FileCheck %s --implicit-check-not=GetGCPhase --implicit-check-not=gcNoRunning
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 -print-after=cj-barrier-lowering -print-module-scope -filter-print-funcs=plain_stack_store -o /dev/null < %s 2>&1 | FileCheck %s --implicit-check-not=GetGCPhase --implicit-check-not=gcNoRunning
;
; ZBarrierSet::AccessBarrier::oop_store_not_in_heap, zBarrierSet.inline.hpp:258.
; Native slots keep their colored store protocol independently of phase.
; A module must not acquire a phase-provider dependency, even as an unused
; declaration. P01's plain-storage proof requires more than a null holder.

@root = global i8 addrspace(1)* null

; CHECK-LABEL: define void @native_store(
; CHECK-NOT: store i8 addrspace(1)*
; CHECK: call void @CJ_MCC_WriteStaticRef(
; CHECK-NOT: store i8 addrspace(1)*
; CHECK: ret void
define void @native_store(i8 addrspace(1)* %value) gc "cangjie" {
  call void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)* %value, i8 addrspace(1)** @root)
  ret void
}

; CHECK-LABEL: define void @unknown_as1_store(
; CHECK-NOT: store i8 addrspace(1)*
; CHECK: call void @CJ_MCC_WriteRefField(
; CHECK-NOT: store i8 addrspace(1)*
; CHECK: ret void
define void @unknown_as1_store(i8 addrspace(1)* %value, i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* null, i8 addrspace(1)* addrspace(1)* %slot)
  ret void
}

; CHECK-LABEL: define void @plain_stack_store(
; CHECK-NOT: call void @CJ_MCC_WriteRefField
; CHECK: store i8 addrspace(1)* %value
; CHECK-NOT: call void @CJ_MCC_WriteRefField
; CHECK: ret void
define void @plain_stack_store(i8 addrspace(1)* %value) gc "cangjie" {
  %plain = alloca i8 addrspace(1)*
  %slot = addrspacecast i8 addrspace(1)** %plain to i8 addrspace(1)* addrspace(1)*
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* null, i8 addrspace(1)* addrspace(1)* %slot)
  call void @escape(i8 addrspace(1)** %plain)
  ret void
}

declare void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)*, i8 addrspace(1)**)
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
declare void @escape(i8 addrspace(1)**)
