; RUN: llc --cangjie-pipeline -mtriple=x86_64 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=aarch64 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; ZGC zBarrierSetAssembler_x86.cpp:305-331: test o, pass (o,p).
; Cangjie value-type storage needs a separate non-heap accessor branch.
define i8 addrspace(1)* @weak(i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
; CHECK-LABEL: define i8 addrspace(1)* @weak(
; CHECK: br i1 %cj.read.inheap.result, label %loadFast, label %loadAccessor
; CHECK: loadFast:
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
; CHECK: loadAccessor:
; CHECK-NEXT: [[NATIVE:%[^ ]+]] = call i8 addrspace(1)* @CJ_MCC_ReadWeakRef(i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot)
; CHECK: loadFinish:
; CHECK-NEXT: [[RESULT:%[^ ]+]] = phi i8 addrspace(1)* [ [[FAST]], %gcNoMarked ], [ [[SLOW]], %gcMarked ], [ [[NATIVE]], %loadAccessor ]
; CHECK: ret i8 addrspace(1)* [[RESULT]]
  %value = call i8 addrspace(1)* @llvm.cj.gcread.weakref(i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot)
  ret i8 addrspace(1)* %value
}
declare i8 addrspace(1)* @llvm.cj.gcread.weakref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
