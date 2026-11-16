; RUN: opt -passes='loop(indvars)' -S %s | FileCheck %s
; Also exercised as a native executable after optimization in the consumer test.

declare {i32, i1} @llvm.smul.with.overflow.i32(i32, i32)

define i32 @mark(i64 %start, i64 %step, i64 %limit) noinline {
; CHECK-LABEL: @mark(
; CHECK: %bounds = icmp ult i64 %j, %limit
entry:
  %enter = icmp slt i64 %start, %limit
  br i1 %enter, label %loop, label %exit
loop:
  %j = phi i64 [ %start, %entry ], [ %next, %body ]
  %count = phi i32 [ 0, %entry ], [ %count.next, %body ]
  %bounds = icmp ult i64 %j, %limit
  br i1 %bounds, label %body, label %fail
body:
  %count.next = add i32 %count, 1
  %next = add nsw i64 %j, %step
  %cont = icmp slt i64 %next, %limit
  br i1 %cont, label %loop, label %exit
fail:
  ret i32 -1
exit:
  %result = phi i32 [ 0, %entry ], [ %count.next, %body ]
  ret i32 %result
}

define i32 @wrap(i64 %start, i64 %step, i64 %limit) noinline {
; CHECK-LABEL: @wrap(
; CHECK: %bounds = icmp ult i64 %j, %limit
entry:
  %enter = icmp slt i64 %start, %limit
  br i1 %enter, label %loop, label %exit
loop:
  %j = phi i64 [ %start, %entry ], [ %next, %body ]
  %count = phi i32 [ 0, %entry ], [ %count.next, %body ]
  %bounds = icmp ult i64 %j, %limit
  br i1 %bounds, label %body, label %fail
body:
  %count.next = add i32 %count, 1
  %next = add i64 %j, %step
  %cont = icmp slt i64 %next, %limit
  br i1 %cont, label %loop, label %exit
fail:
  ret i32 -1
exit:
  %result = phi i32 [ 0, %entry ], [ %count.next, %body ]
  ret i32 %result
}

define i32 @square(i32 noundef %seed, i32 %limit) noinline {
; CHECK-LABEL: @square(
; CHECK: call { i32, i1 } @llvm.smul.with.overflow.i32
; CHECK: br i1 %overflow,
; CHECK-NOT: icmp ult i32 %j,
; CHECK: define i32 @main(
entry:
  %mul = call {i32, i1} @llvm.smul.with.overflow.i32(i32 %seed, i32 %seed)
  %start = extractvalue {i32, i1} %mul, 0
  %overflow = extractvalue {i32, i1} %mul, 1
  br i1 %overflow, label %overflow.fail, label %guard
 guard:
  %enter = icmp slt i32 %start, %limit
  br i1 %enter, label %loop, label %exit
loop:
  %j = phi i32 [ %start, %guard ], [ %next, %body ]
  %count = phi i32 [ 0, %guard ], [ %count.next, %body ]
  %bounds = icmp ult i32 %j, %limit
  br i1 %bounds, label %body, label %bounds.fail
body:
  %count.next = add i32 %count, 1
  %next = add nsw i32 %j, 1
  %cont = icmp slt i32 %next, %limit
  br i1 %cont, label %loop, label %exit
bounds.fail:
  ret i32 -1
overflow.fail:
  ret i32 -2
exit:
  %result = phi i32 [ 0, %guard ], [ %count.next, %body ]
  ret i32 %result
}

define i32 @main() {
  %a = call i32 @mark(i64 -1, i64 1, i64 3)
  %ca = icmp eq i32 %a, -1
  %b = call i32 @mark(i64 2, i64 -1, i64 3)
  %cb = icmp eq i32 %b, -1
  %c = call i32 @mark(i64 3, i64 1, i64 3)
  %cc = icmp eq i32 %c, 0
  %d = call i32 @mark(i64 0, i64 1, i64 0)
  %cd = icmp eq i32 %d, 0
  %e = call i32 @mark(i64 0, i64 2, i64 3)
  %ce = icmp eq i32 %e, 2
  %f = call i32 @wrap(i64 9223372036854775806, i64 2, i64 9223372036854775807)
  %cf = icmp eq i32 %f, -1
  %g = call i32 @square(i32 2, i32 8)
  %cg = icmp eq i32 %g, 4
  %h = call i32 @square(i32 -2, i32 8)
  %ch = icmp eq i32 %h, 4
  %i = call i32 @square(i32 3, i32 8)
  %ci = icmp eq i32 %i, 0
  %k = call i32 @square(i32 46341, i32 8)
  %ck = icmp eq i32 %k, -2
  %ok1 = and i1 %ca, %cb
  %ok2 = and i1 %cc, %cd
  %ok3 = and i1 %ce, %cf
  %ok4 = and i1 %cg, %ch
  %ok5 = and i1 %ci, %ck
  %ok6 = and i1 %ok1, %ok2
  %ok7 = and i1 %ok3, %ok4
  %ok8 = and i1 %ok6, %ok7
  %ok = and i1 %ok8, %ok5
  %ret = select i1 %ok, i32 0, i32 1
  ret i32 %ret
}
