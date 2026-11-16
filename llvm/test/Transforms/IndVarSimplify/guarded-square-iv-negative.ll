; RUN: opt -passes='loop(indvars)' -S %s | FileCheck %s

declare {i64, i1} @llvm.smul.with.overflow.i64(i64, i64)
declare void @use(i64)
declare void @fail()
declare void @escape({i64, i1})

define void @undef(i64 %x, i64 %limit, i1 %again) {
; CHECK-LABEL: @undef(
; CHECK: %bounds = icmp ult i64 %j, %limit
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

define void @different_operands(i64 noundef %x, i64 %limit, i1 %again) {
; CHECK-LABEL: @different_operands(
; CHECK: %bounds = icmp ult i64 %j, %limit
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
  %mul = call {i64, i1} @llvm.smul.with.overflow.i64(i64 %x, i64 %limit)
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

define void @negative_step(i64 noundef %x, i64 %limit, i1 %again) {
; CHECK-LABEL: @negative_step(
; CHECK: %bounds = icmp ult i64 %j, %limit
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
  %next = add nsw i64 %j, -2
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

define void @wrapping_step(i64 noundef %x, i64 %limit, i1 %again) {
; CHECK-LABEL: @wrapping_step(
; CHECK: %bounds = icmp ult i64 %j, %limit
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
  %next = add i64 %j, 2
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

define void @negative_start(i64 noundef %x, i64 %limit, i1 %again) {
; CHECK-LABEL: @negative_start(
; CHECK: %bounds = icmp ult i64 %j, %limit
entry:
  br label %outer
outer:
  %start = phi i64 [ -4, %entry ], [ %square, %advance ]
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

define void @equal_entry(i64 noundef %x, i64 %limit, i1 %again) {
; CHECK-LABEL: @equal_entry(
; CHECK: %bounds = icmp ult i64 %j, %limit
entry:
  br label %outer
outer:
  %start = phi i64 [ 4, %entry ], [ %square, %advance ]
  %enter = icmp sle i64 %start, %limit
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

define void @equal_latch(i64 noundef %x, i64 %limit, i1 %again) {
; CHECK-LABEL: @equal_latch(
; CHECK: %bounds = icmp ult i64 %j, %limit
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
  %cont = icmp sle i64 %next, %limit
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

define void @overflow_true(i64 noundef %x, i64 %limit, i1 %again) {
; CHECK-LABEL: @overflow_true(
; CHECK: %bounds = icmp ult i64 %j, %limit
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
  br i1 %overflow, label %outer, label %overflow.fail
bounds.fail:
  call void @fail()
  ret void
overflow.fail:
  call void @fail()
  ret void
exit:
  ret void
}

define void @missing_overflow(i64 noundef %x, i64 %limit, i1 %again) {
; CHECK-LABEL: @missing_overflow(
; CHECK: %bounds = icmp ult i64 %j, %limit
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
  br label %outer
bounds.fail:
  call void @fail()
  ret void
overflow.fail:
  call void @fail()
  ret void
exit:
  ret void
}

define void @aggregate_escape(i64 noundef %x, i64 %limit, i1 %again) {
; CHECK-LABEL: @aggregate_escape(
; CHECK: %bounds = icmp ult i64 %j, %limit
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
  call void @escape({i64, i1} %mul)
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

define void @unknown_step(i64 noundef %x, i64 %limit, i64 %step, i1 %again) {
; CHECK-LABEL: @unknown_step(
; CHECK: %bounds = icmp ult i64 %j, %limit
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
  %next = add nsw i64 %j, %step
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

define void @undef_square(i64 noundef %x, i64 %limit, i1 %again) {
; CHECK-LABEL: @undef_square(
; CHECK: %bounds = icmp ult i64 %j, %limit
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
  %mul = call {i64, i1} @llvm.smul.with.overflow.i64(i64 undef, i64 undef)
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

define void @undef_recurrence_entry(i64 noundef %x, i64 %limit, i1 %again) {
; CHECK-LABEL: @undef_recurrence_entry(
; CHECK: %bounds = icmp ult i64 %j, %limit
entry:
  br label %outer
outer:
  %p = phi i64 [ undef, %entry ], [ %p.next, %advance ]
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

define void @poison_recurrence_entry(i64 noundef %x, i64 %limit, i1 %again) {
; CHECK-LABEL: @poison_recurrence_entry(
; CHECK: %bounds = icmp ult i64 %j, %limit
entry:
  br label %outer
outer:
  %p = phi i64 [ poison, %entry ], [ %p.next, %advance ]
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

define void @unknown_recurrence_step(i64 noundef %x, i64 %limit, i64 %step, i1 %again) {
; CHECK-LABEL: @unknown_recurrence_step(
; CHECK: %bounds = icmp ult i64 %j, %limit
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
  %p.next = add nuw nsw i64 %p, %step
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

define void @missing_latch_guard(i64 noundef %x, i64 %limit, i1 %again) {
; CHECK-LABEL: @missing_latch_guard(
; CHECK: %bounds = icmp ult i64 %j, %limit
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
  br i1 %again, label %loop, label %advance
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

define void @missing_entry_guard(i64 noundef %x, i64 %limit, i1 %again) {
; CHECK-LABEL: @missing_entry_guard(
; CHECK: %bounds = icmp ult i64 %j, %limit
entry:
  br label %outer
outer:
  %p = phi i64 [ 2, %entry ], [ %p.next, %advance ]
  %start = phi i64 [ 4, %entry ], [ %square, %advance ]
  %enter = icmp slt i64 %start, %limit
  br i1 %again, label %preheader, label %exit
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

