; A loop whose body is nothing but a heap ref write.
;
; The old GC-state loop duplication cloned such a loop and hoisted the phase
; check into the preheader (`.pin` blocks, gcNoRunning/gcRunning arms). That is
; incompatible with the colour store fast path, which splits every scalar heap
; ref write into its own then/else -- the cloned barrier set no longer
; describes the loop body. The colour ABI is unconditional, so the duplication
; is gone; this test is the guard that it stays gone.

; RUN: llc --cangjie-pipeline -mtriple=x86_64 \
; RUN:   -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 \
; RUN:   | FileCheck %s

define void @foo1(i8 addrspace(1)* %arg0, i64 %arg1, i8 addrspace(1)* %arg2) gc "cangjie" {
; CHECK-LABEL: define void @foo1
; CHECK-NOT: .pin
; CHECK-NOT: gcNoRunning
; CHECK: getelementptr i8, i8* %cj.gcdata{{[0-9]*}}, i64 32
; CHECK: storeSlow:
; CHECK: call void @CJ_MCC_StoreBarrierOnHeapField
; CHECK: storeFinish:
; CHECK: getelementptr i8, i8* %cj.gcdata{{[0-9]*}}, i64 24
; CHECK: ret void

entry:
  %a = bitcast i8 addrspace(1)* %arg0 to i8 addrspace(1)* addrspace(1) *
  br label %loop.preheader

loop.preheader:
  br label %arr.end1

arr.end1:
  %i = phi i64 [ %add.i, %arr.end1 ], [ 0, %loop.preheader]
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %arg2, i8 addrspace(1)* %arg0, i8 addrspace(1)* addrspace(1)* %a, i32 1)
  %add.i = add i64 %i, 1
  %icmpslt = icmp slt i64 %add.i, %arg1
  br i1 %icmpslt, label %arr.end1, label %loopexit

loopexit:
  ret void
}

declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)
