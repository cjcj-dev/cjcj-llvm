; RUN: opt -opaque-pointers -S -cangjie-pipeline -passes='function(loop-mssa(licm))' %s | FileCheck %s
; RUN: opt -S -cangjie-pipeline -passes='function(loop-mssa(licm))' %s | FileCheck %s
;
; A condition independent of the pointer is not proof that the access is valid.
; Cover both the generic dereferenceability query and CJ partial speculation.
; In-range loads must still hoist. No GC or runtime state is needed for this rule.
target datalayout = "e-m:e-p:64:64-i64:64-n8:16:32:64-S128"

; CHECK-LABEL: define i64 @unknown_extent(
; CHECK: entry:
; CHECK-NOT: load i8,
; CHECK: read:
; CHECK: %value = load i8
define i64 @unknown_extent(i8*  %base, i64 %offset, i1* %flag, i64 %count) {
entry:
  %address = getelementptr i8, i8* %base, i64 %offset
  %typed = bitcast i8* %address to i8*
  br label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %acc = phi i64 [ 0, %entry ], [ %result, %latch ]
  %run = load i1, i1* %flag, align 1
  br i1 %run, label %read, label %latch
read:
  %value = load i8, i8* %typed, align 1
  %extended = zext i8 %value to i64
  %sum = add i64 %acc, %extended
  br label %latch
latch:
  %result = phi i64 [ %acc, %loop ], [ %sum, %read ]
  %next = add i64 %i, 1
  %more = icmp ult i64 %next, %count
  br i1 %more, label %loop, label %exit
exit:
  ret i64 %result
}

; CHECK-LABEL: define i64 @past_end(
; CHECK: entry:
; CHECK-NOT: load i8,
; CHECK: read:
; CHECK: %value = load i8
define i64 @past_end(i8* dereferenceable(8) %base, i64 %offset, i1* %flag, i64 %count) {
entry:
  %address = getelementptr i8, i8* %base, i64 8
  %typed = bitcast i8* %address to i8*
  br label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %acc = phi i64 [ 0, %entry ], [ %result, %latch ]
  %run = load i1, i1* %flag, align 1
  br i1 %run, label %read, label %latch
read:
  %value = load i8, i8* %typed, align 1
  %extended = zext i8 %value to i64
  %sum = add i64 %acc, %extended
  br label %latch
latch:
  %result = phi i64 [ %acc, %loop ], [ %sum, %read ]
  %next = add i64 %i, 1
  %more = icmp ult i64 %next, %count
  br i1 %more, label %loop, label %exit
exit:
  ret i64 %result
}

; CHECK-LABEL: define i64 @crosses_end(
; CHECK: entry:
; CHECK-NOT: load i32,
; CHECK: read:
; CHECK: %value = load i32
define i64 @crosses_end(i8* dereferenceable(4) %base, i64 %offset, i1* %flag, i64 %count) {
entry:
  %address = getelementptr i8, i8* %base, i64 2
  %typed = bitcast i8* %address to i32*
  br label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %acc = phi i64 [ 0, %entry ], [ %result, %latch ]
  %run = load i1, i1* %flag, align 1
  br i1 %run, label %read, label %latch
read:
  %value = load i32, i32* %typed, align 1
  %extended = zext i32 %value to i64
  %sum = add i64 %acc, %extended
  br label %latch
latch:
  %result = phi i64 [ %acc, %loop ], [ %sum, %read ]
  %next = add i64 %i, 1
  %more = icmp ult i64 %next, %count
  br i1 %more, label %loop, label %exit
exit:
  ret i64 %result
}

; CHECK-LABEL: define i64 @insufficient_alignment(
; CHECK: entry:
; CHECK-NOT: load i32,
; CHECK: read:
; CHECK: %value = load i32
define i64 @insufficient_alignment(i8* align 1 dereferenceable(8) %base, i64 %offset, i1* %flag, i64 %count) {
entry:
  %address = getelementptr i8, i8* %base, i64 1
  %typed = bitcast i8* %address to i32*
  br label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %acc = phi i64 [ 0, %entry ], [ %result, %latch ]
  %run = load i1, i1* %flag, align 1
  br i1 %run, label %read, label %latch
read:
  %value = load i32, i32* %typed, align 4
  %extended = zext i32 %value to i64
  %sum = add i64 %acc, %extended
  br label %latch
latch:
  %result = phi i64 [ %acc, %loop ], [ %sum, %read ]
  %next = add i64 %i, 1
  %more = icmp ult i64 %next, %count
  br i1 %more, label %loop, label %exit
exit:
  ret i64 %result
}

; CHECK-LABEL: define i64 @in_range(
; CHECK: entry:
; CHECK: %value = load i32
; CHECK: br label %loop
define i64 @in_range(i8* align 8 dereferenceable(8) %base, i64 %offset, i1* %flag, i64 %count) {
entry:
  %address = getelementptr i8, i8* %base, i64 4
  %typed = bitcast i8* %address to i32*
  br label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %acc = phi i64 [ 0, %entry ], [ %result, %latch ]
  %run = load i1, i1* %flag, align 1
  br i1 %run, label %read, label %latch
read:
  %value = load i32, i32* %typed, align 4
  %extended = zext i32 %value to i64
  %sum = add i64 %acc, %extended
  br label %latch
latch:
  %result = phi i64 [ %acc, %loop ], [ %sum, %read ]
  %next = add i64 %i, 1
  %more = icmp ult i64 %next, %count
  br i1 %more, label %loop, label %exit
exit:
  ret i64 %result
}
