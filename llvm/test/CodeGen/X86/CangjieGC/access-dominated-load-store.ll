; RUN: opt -passes=cj-ir-verifier -disable-output < %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O0 -enable-gc-fast-path=false -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 -enable-gc-fast-path=false -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; ZGC zBarrierSetC2.cpp:514-545; barrierSetC2.cpp:1106-1156.
; Preserve the access across a potentially aliasing primitive write; only its
; barrier may disappear. No pre-attached elision metadata supplies the proof.
target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
define i8 addrspace(1)* @probe(i8* %type, i8 addrspace(1)* %value, i64* %alias, i64 %word) gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i32)* @CJ_MCC_NewObject, i32 2, i32 0, i8* %type, i32 64)
  %heap = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  ; End allocation dominance so this fixture isolates access dominance.
  %allocation.boundary1 = call token (...) @llvm.cj.gc.statepoint(i64 101, i32 0, void ()* @allocation_boundary, i32 0, i32 0)
  %field = getelementptr inbounds i8, i8 addrspace(1)* %heap, i64 8
  %slot = bitcast i8 addrspace(1)* %field to i8 addrspace(1)* addrspace(1)*
  %first = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %heap, i8 addrspace(1)* addrspace(1)* %slot)
; CHECK-LABEL: define i8 addrspace(1)* @probe(
; CHECK: store volatile i64 %word, i64* %alias
; CHECK: cj.store.prev.low
; CHECK: call void @CJ_MCC_StoreBarrierOnHeapField
; CHECK: store volatile i64 %cj.store.colored{{[0-9]*}}
; CHECK: ret i8 addrspace(1)* %value
  store volatile i64 %word, i64* %alias
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %heap, i8 addrspace(1)* addrspace(1)* %slot, i32 1)
  ret i8 addrspace(1)* %value
}
declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare token @llvm.cj.gc.statepoint(...)
declare i8 addrspace(1)* @llvm.cj.gc.result(token)
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)
declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
declare void @allocation_boundary()
