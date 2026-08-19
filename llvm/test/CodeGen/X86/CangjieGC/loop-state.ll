; RUN: llc --cangjie-pipeline -mtriple=x86_64 -cj-gcstate-dup-loop=true \
; RUN:   -cj-generational-post-barrier=false < %s | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -cj-gcstate-dup-loop=true \
; RUN:   -cj-generational-post-barrier -print-after=cj-barrier-lowering \
; RUN:   -o /dev/null < %s 2>&1 | FileCheck %s --check-prefix=GEN

define void @foo1(i8 addrspace(1)* %arg0, i64 %arg1, i8 addrspace(1)* %arg2) gc "cangjie" {
; CHECK: foo1
; CHECK: %entry
; CHECK: movq    8(%r15), %rax
; CHECK: movl    (%rax), %eax
; CHECK: cmpl    $8, %eax
; CHECK: %arr.end1
; CHECK: movq    %r14, (%r13)
; CHECK: %gcNoRunning
; CHECK: movq    %r14, (%r13)
; CHECK: %arr.end1.pin
; CHECK: movq    8(%r15), %rax
; CHECK: movl    (%rax), %eax
; CHECK: cmpl    $9, %eax
; CHECK: %gcRunning
; CHECK: callq   CJ_MCC_WriteRefField@PLT
; GEN-LABEL: define void @foo1
; GEN-NOT: .pin
; GEN-NOT: gcNoRunning
; GEN: load i64, i64* @g_cjStoreBadMask
; GEN: storeFinish:
; GEN: load i64, i64* @g_cjStoreGoodMask
; GEN: gcStoreBad:
; GEN: call void @CJ_MCC_WriteRefField
; GEN: ret void

entry:
  %a = bitcast i8 addrspace(1)* %arg0 to i8 addrspace(1)* addrspace(1) *
  br label %loop.preheader

loop.preheader:
  br label %arr.end1

arr.end1:
  %i = phi i64 [ %add.i, %arr.end1 ], [ 0, %loop.preheader]
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %arg2, i8 addrspace(1)* %arg0, i8 addrspace(1)* addrspace(1)* %a)
  %add.i = add i64 %i, 1
  %icmpslt = icmp slt i64 %add.i, %arg1
  br i1 %icmpslt, label %arr.end1, label %loopexit

loopexit:
  ret void
}

declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)* nocapture, i8 addrspace(1)* addrspace(1)* nocapture)
