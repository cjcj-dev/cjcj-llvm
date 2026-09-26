; RUN: llc --cangjie-pipeline -mtriple=x86_64 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=aarch64 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; ZGC zBarrierSetAssembler_x86.cpp:305-331: test o, pass (o,p).
; Cangjie value-type storage needs a separate non-heap accessor branch.
; Keep the heap-origin proof across a safepoint, without allocation-dominated
; barrier elision (gc/shared/c2/barrierSetC2.cpp:1116-1122).
; The preloaded value, both path results, and the returned phi stay observable.
define i8 addrspace(1)* @proven(i8* %type) gc "cangjie" {
; CHECK-LABEL: define i8 addrspace(1)* @proven(
; CHECK-NOT: g_cjHeapRangeCount
; CHECK: [[O:%[^ ]+]] = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %slot
; CHECK: [[BITS:%[^ ]+]] = ptrtoint i8 addrspace(1)* [[O]] to i64
; CHECK: getelementptr i8, i8* %cj.gcdata{{[0-9]*}}, i64 8
; CHECK: [[BAD:%[^ ]+]] = and i64 [[BITS]], %cj.loadbadmask
; CHECK: [[GOOD:%[^ ]+]] = icmp eq i64 [[BAD]], 0
; CHECK: br i1 [[GOOD]], label %gcNoMarked, label %gcMarked
; CHECK: gcMarked:
; CHECK-NEXT: [[SLOW:%[^ ]+]] = call i8 addrspace(1)* @CJ_MCC_LoadBarrierOnOopFieldPreloaded(i8 addrspace(1)* [[O]], i8 addrspace(1)* addrspace(1)* %slot)
; CHECK-NEXT: br label %loadFinish
; CHECK: gcNoMarked:
; CHECK: [[FAST:%[^ ]+]] = inttoptr i64 {{%[^ ]+}} to i8 addrspace(1)*
; CHECK-NOT: loadAccessor:
; CHECK: loadFinish:
; CHECK-NEXT: [[RESULT:%[^ ]+]] = phi i8 addrspace(1)* [ [[FAST]], %gcNoMarked ], [ [[SLOW]], %gcMarked ]
; CHECK: ret i8 addrspace(1)* [[RESULT]]
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i32)* @CJ_MCC_NewObject, i32 2, i32 0, i8* %type, i32 64)
  %allocated = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  %point = call token (...) @llvm.cj.gc.statepoint(i64 1, i32 0, void ()* @safepoint, i32 0, i32 0) [ "gc-live"(i8 addrspace(1)* %allocated) ]
  %base = call i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token %point, i32 0, i32 0)
  %field = getelementptr inbounds i8, i8 addrspace(1)* %base, i64 8
  %slot = bitcast i8 addrspace(1)* %field to i8 addrspace(1)* addrspace(1)*
  %value = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot)
  ret i8 addrspace(1)* %value
}
declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare token @llvm.cj.gc.statepoint(...)
declare i8 addrspace(1)* @llvm.cj.gc.result(token)
declare void @safepoint()
declare i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token, i32 immarg, i32 immarg)
