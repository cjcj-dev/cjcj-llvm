; RUN: opt -aa-pipeline=basic-aa -passes=loop-idiom -S < %s | FileCheck %s
;
; A loop that copies whole aggregate elements leaf by leaf (one load/store pair
; per field, each narrower than the element stride) is recognized like a single
; element-sized store of a loaded value: memmove when the ranges overlap in the
; forward direction, memcpy when they do not. Pointer-valued leaves, gaps,
; mismatched leaf offsets and backward overlap are left alone.

target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

%pair = type { i64, i64 }
%refpair = type { i8 addrspace(1)*, i64 }
%gappy = type { i64, i32, i32 }

; a[i - 1] = a[i] for i in 1..n: forward shift of {i64, i64} elements.
; CHECK-LABEL: @shift_pairs(
; CHECK: call void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)* align 8 %{{.*}}, i8 addrspace(1)* align 8 %{{.*}}, i64 %{{.*}}, i1 false)
; CHECK-NOT: store i64
; CHECK: ret void
define void @shift_pairs(%pair addrspace(1)* %a, i64 %n) {
entry:
  %guard = icmp sgt i64 %n, 1
  br i1 %guard, label %loop, label %exit
loop:
  %i = phi i64 [ 1, %entry ], [ %i.next, %loop ]
  %im1 = add nsw i64 %i, -1
  %src.x = getelementptr inbounds %pair, %pair addrspace(1)* %a, i64 %i, i32 0
  %src.y = getelementptr inbounds %pair, %pair addrspace(1)* %a, i64 %i, i32 1
  %dst.x = getelementptr inbounds %pair, %pair addrspace(1)* %a, i64 %im1, i32 0
  %dst.y = getelementptr inbounds %pair, %pair addrspace(1)* %a, i64 %im1, i32 1
  %x = load i64, i64 addrspace(1)* %src.x, align 8
  %y = load i64, i64 addrspace(1)* %src.y, align 8
  store i64 %x, i64 addrspace(1)* %dst.x, align 8
  store i64 %y, i64 addrspace(1)* %dst.y, align 8
  %i.next = add nuw nsw i64 %i, 1
  %done = icmp eq i64 %i.next, %n
  br i1 %done, label %exit, label %loop
exit:
  ret void
}

; d[i] = s[i] between distinct arrays, leaves interleaved: memcpy.
; CHECK-LABEL: @copy_pairs(
; CHECK: call void @llvm.memcpy.p0i8.p0i8.i64(i8* align 8 %{{.*}}, i8* align 8 %{{.*}}, i64 %{{.*}}, i1 false)
; CHECK-NOT: store i64
; CHECK: ret void
define void @copy_pairs(%pair* noalias %d, %pair* noalias %s, i64 %n) {
entry:
  %guard = icmp sgt i64 %n, 0
  br i1 %guard, label %loop, label %exit
loop:
  %i = phi i64 [ 0, %entry ], [ %i.next, %loop ]
  %s.x = getelementptr inbounds %pair, %pair* %s, i64 %i, i32 0
  %d.x = getelementptr inbounds %pair, %pair* %d, i64 %i, i32 0
  %x = load i64, i64* %s.x, align 8
  store i64 %x, i64* %d.x, align 8
  %s.y = getelementptr inbounds %pair, %pair* %s, i64 %i, i32 1
  %d.y = getelementptr inbounds %pair, %pair* %d, i64 %i, i32 1
  %y = load i64, i64* %s.y, align 8
  store i64 %y, i64* %d.y, align 8
  %i.next = add nuw nsw i64 %i, 1
  %done = icmp eq i64 %i.next, %n
  br i1 %done, label %exit, label %loop
exit:
  ret void
}

; A pointer-valued leaf never joins a chain, so the element is not covered.
; CHECK-LABEL: @shift_refpairs(
; CHECK-NOT: call void @llvm.mem
; CHECK: store i8 addrspace(1)* %{{.*}}
; CHECK: ret void
define void @shift_refpairs(%refpair addrspace(1)* %a, i64 %n) {
entry:
  %guard = icmp sgt i64 %n, 1
  br i1 %guard, label %loop, label %exit
loop:
  %i = phi i64 [ 1, %entry ], [ %i.next, %loop ]
  %im1 = add nsw i64 %i, -1
  %src.r = getelementptr inbounds %refpair, %refpair addrspace(1)* %a, i64 %i, i32 0
  %src.v = getelementptr inbounds %refpair, %refpair addrspace(1)* %a, i64 %i, i32 1
  %dst.r = getelementptr inbounds %refpair, %refpair addrspace(1)* %a, i64 %im1, i32 0
  %dst.v = getelementptr inbounds %refpair, %refpair addrspace(1)* %a, i64 %im1, i32 1
  %r = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %src.r, align 8
  %v = load i64, i64 addrspace(1)* %src.v, align 8
  store i8 addrspace(1)* %r, i8 addrspace(1)* addrspace(1)* %dst.r, align 8
  store i64 %v, i64 addrspace(1)* %dst.v, align 8
  %i.next = add nuw nsw i64 %i, 1
  %done = icmp eq i64 %i.next, %n
  br i1 %done, label %exit, label %loop
exit:
  ret void
}

; Leaves at offsets 0 and 12 leave bytes 8..12 uncopied.
; CHECK-LABEL: @copy_with_gap(
; CHECK-NOT: call void @llvm.mem
; CHECK: ret void
define void @copy_with_gap(%gappy* noalias %d, %gappy* noalias %s, i64 %n) {
entry:
  %guard = icmp sgt i64 %n, 0
  br i1 %guard, label %loop, label %exit
loop:
  %i = phi i64 [ 0, %entry ], [ %i.next, %loop ]
  %s.a = getelementptr inbounds %gappy, %gappy* %s, i64 %i, i32 0
  %s.c = getelementptr inbounds %gappy, %gappy* %s, i64 %i, i32 2
  %d.a = getelementptr inbounds %gappy, %gappy* %d, i64 %i, i32 0
  %d.c = getelementptr inbounds %gappy, %gappy* %d, i64 %i, i32 2
  %a = load i64, i64* %s.a, align 8
  %c = load i32, i32* %s.c, align 4
  store i64 %a, i64* %d.a, align 8
  store i32 %c, i32* %d.c, align 4
  %i.next = add nuw nsw i64 %i, 1
  %done = icmp eq i64 %i.next, %n
  br i1 %done, label %exit, label %loop
exit:
  ret void
}

; Leaves swapped between source and destination are not an element copy.
; CHECK-LABEL: @copy_swapped(
; CHECK-NOT: call void @llvm.mem
; CHECK: ret void
define void @copy_swapped(%pair* noalias %d, %pair* noalias %s, i64 %n) {
entry:
  %guard = icmp sgt i64 %n, 0
  br i1 %guard, label %loop, label %exit
loop:
  %i = phi i64 [ 0, %entry ], [ %i.next, %loop ]
  %s.x = getelementptr inbounds %pair, %pair* %s, i64 %i, i32 0
  %s.y = getelementptr inbounds %pair, %pair* %s, i64 %i, i32 1
  %d.x = getelementptr inbounds %pair, %pair* %d, i64 %i, i32 0
  %d.y = getelementptr inbounds %pair, %pair* %d, i64 %i, i32 1
  %x = load i64, i64* %s.x, align 8
  %y = load i64, i64* %s.y, align 8
  store i64 %y, i64* %d.x, align 8
  store i64 %x, i64* %d.y, align 8
  %i.next = add nuw nsw i64 %i, 1
  %done = icmp eq i64 %i.next, %n
  br i1 %done, label %exit, label %loop
exit:
  ret void
}

; a[i + 1] = a[i] for increasing i propagates a[0]; that is not a memmove.
; CHECK-LABEL: @shift_pairs_backward(
; CHECK-NOT: call void @llvm.mem
; CHECK: ret void
define void @shift_pairs_backward(%pair addrspace(1)* %a, i64 %n) {
entry:
  %guard = icmp sgt i64 %n, 0
  br i1 %guard, label %loop, label %exit
loop:
  %i = phi i64 [ 0, %entry ], [ %i.next, %loop ]
  %ip1 = add nuw nsw i64 %i, 1
  %src.x = getelementptr inbounds %pair, %pair addrspace(1)* %a, i64 %i, i32 0
  %src.y = getelementptr inbounds %pair, %pair addrspace(1)* %a, i64 %i, i32 1
  %dst.x = getelementptr inbounds %pair, %pair addrspace(1)* %a, i64 %ip1, i32 0
  %dst.y = getelementptr inbounds %pair, %pair addrspace(1)* %a, i64 %ip1, i32 1
  %x = load i64, i64 addrspace(1)* %src.x, align 8
  %y = load i64, i64 addrspace(1)* %src.y, align 8
  store i64 %x, i64 addrspace(1)* %dst.x, align 8
  store i64 %y, i64 addrspace(1)* %dst.y, align 8
  %i.next = add nuw nsw i64 %i, 1
  %done = icmp eq i64 %i.next, %n
  br i1 %done, label %exit, label %loop
exit:
  ret void
}
