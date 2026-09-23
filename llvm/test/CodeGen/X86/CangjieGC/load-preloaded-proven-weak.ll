; RUN: llc --cangjie-pipeline -mtriple=x86_64 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=aarch64 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; ZGC zBarrierSetAssembler_x86.cpp:305-331: test o, pass (o,p).
; Cangjie value-type storage needs a separate non-heap accessor branch.
define i8 addrspace(1)* @proven_weak(i8* %type) gc "cangjie" {
; CHECK-LABEL: define i8 addrspace(1)* @proven_weak(
; CHECK-NOT: g_cjHeapRangeCount
; CHECK: [[O:%[^ ]+]] = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %slot
; CHECK: [[BITS:%[^ ]+]] = ptrtoint i8 addrspace(1)* [[O]] to i64
; CHECK: getelementptr i8, i8* %cj.gcdata{{[0-9]*}}, i64 16
; CHECK: [[BAD:%[^ ]+]] = and i64 [[BITS]], %cj.markbadmask
; CHECK: [[GOOD:%[^ ]+]] = icmp eq i64 [[BAD]], 0
; CHECK: br i1 [[GOOD]], label %gcNoMarked, label %gcMarked
; CHECK: gcMarked:
; CHECK-NEXT: [[SLOW:%[^ ]+]] = call i8 addrspace(1)* @CJ_MCC_LoadBarrierOnWeakOopFieldPreloaded(i8 addrspace(1)* [[O]], i8 addrspace(1)* addrspace(1)* %slot)
; CHECK-NEXT: br label %loadFinish
; CHECK: gcNoMarked:
; CHECK: [[FAST:%[^ ]+]] = inttoptr i64 {{%[^ ]+}} to i8 addrspace(1)*
; CHECK-NOT: loadAccessor:
; CHECK: loadFinish:
; CHECK-NEXT: [[RESULT:%[^ ]+]] = phi i8 addrspace(1)* [ [[FAST]], %gcNoMarked ], [ [[SLOW]], %gcMarked ]
; CHECK: ret i8 addrspace(1)* [[RESULT]]
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i32)* @CJ_MCC_NewObject, i32 2, i32 0, i8* %type, i32 64)
  %base = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  %field = getelementptr inbounds i8, i8 addrspace(1)* %base, i64 8
  %slot = bitcast i8 addrspace(1)* %field to i8 addrspace(1)* addrspace(1)*
  %value = call i8 addrspace(1)* @llvm.cj.gcread.weakref(i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot)
  ret i8 addrspace(1)* %value
}
declare i8 addrspace(1)* @llvm.cj.gcread.weakref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare token @llvm.cj.gc.statepoint(...)
declare i8 addrspace(1)* @llvm.cj.gc.result(token)
