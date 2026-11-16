; RUN: opt -passes='loop(indvars)' -S %s | FileCheck %s
;
; A checked square carried by an outer PHI. The square operand is noundef;
; without that qualification two undef operand uses need not be equal.
declare {i64, i1} @llvm.smul.with.overflow.i64(i64, i64)
declare void @use(i64)
declare void @fail()

define void @guarded_square(i64 noundef %x, i64 %limit, i1 %again) {
; CHECK-LABEL: @guarded_square(
; CHECK-NOT: icmp ult i64 %j,
; CHECK: ret void
entry:
  br label %outer
outer:
  %start = phi i64 [ 4, %entry ], [ %square, %advance ]
  %enter = icmp slt i64 %start, %limit
  br i1 %enter, label %preheader, label %exit
preheader:
  br label %loop
loop:
  %j = phi i64 [ %start, %preheader ], [ %next, %body ]
  %bounds = icmp ult i64 %j, %limit
  br i1 %bounds, label %body, label %bounds.fail
body:
  call void @use(i64 %j)
  %next = add nsw i64 %j, 2
  %cont = icmp slt i64 %next, %limit
  br i1 %cont, label %loop, label %advance
advance:
  %mul = call {i64, i1} @llvm.smul.with.overflow.i64(i64 %x, i64 %x)
  %square = extractvalue {i64, i1} %mul, 0
  %overflow = extractvalue {i64, i1} %mul, 1
  br i1 %overflow, label %overflow.fail, label %outer
bounds.fail:
  call void @fail()
  ret void
overflow.fail:
  call void @fail()
  ret void
exit:
  ret void
}

; The same shape with the actual outer constant-step recurrence.
define void @real_recurrence(i64 noundef %x, i64 %limit, i1 %again) {
; CHECK-LABEL: @real_recurrence(
; CHECK-NOT: icmp ult i64 %j,
; CHECK: ret void
entry:
  br label %outer
outer:
  %p = phi i64 [ 2, %entry ], [ %p.next, %advance ]
  %start = phi i64 [ 4, %entry ], [ %square, %advance ]
  %enter = icmp slt i64 %start, %limit
  br i1 %enter, label %preheader, label %exit
preheader:
  br label %loop
loop:
  %j = phi i64 [ %start, %preheader ], [ %next, %body ]
  %bounds = icmp ult i64 %j, %limit
  br i1 %bounds, label %body, label %bounds.fail
body:
  call void @use(i64 %j)
  %next = add nsw i64 %j, %p
  %cont = icmp slt i64 %next, %limit
  br i1 %cont, label %loop, label %advance
advance:
  %p.next = add nuw nsw i64 %p, 1
  %mul = call {i64, i1} @llvm.smul.with.overflow.i64(i64 %p.next, i64 %p.next)
  %square = extractvalue {i64, i1} %mul, 0
  %overflow = extractvalue {i64, i1} %mul, 1
  br i1 %overflow, label %overflow.fail, label %outer
bounds.fail:
  call void @fail()
  ret void
overflow.fail:
  call void @fail()
  ret void
exit:
  ret void
}

declare {i32, i1} @llvm.smul.with.overflow.i32(i32, i32)
declare void @use32(i32)

define void @guarded_square_i32(i32 noundef %x, i32 %limit, i1 %again) {
; CHECK-LABEL: @guarded_square_i32(
; CHECK-NOT: icmp ult i32 %j,
; CHECK: ret void
entry:
  br label %outer
outer:
  %start = phi i32 [ 4, %entry ], [ %square, %advance ]
  %enter = icmp slt i32 %start, %limit
  br i1 %enter, label %preheader, label %exit
preheader:
  br label %loop
loop:
  %j = phi i32 [ %start, %preheader ], [ %next, %body ]
  %bounds = icmp ult i32 %j, %limit
  br i1 %bounds, label %body, label %bounds.fail
body:
  call void @use32(i32 %j)
  %next = add nsw i32 %j, 2
  %cont = icmp slt i32 %next, %limit
  br i1 %cont, label %loop, label %advance
advance:
  %mul = call {i32, i1} @llvm.smul.with.overflow.i32(i32 %x, i32 %x)
  %square = extractvalue {i32, i1} %mul, 0
  %overflow = extractvalue {i32, i1} %mul, 1
  br i1 %overflow, label %overflow.fail, label %outer
bounds.fail:
  call void @fail()
  ret void
overflow.fail:
  call void @fail()
  ret void
exit:
  ret void
}
