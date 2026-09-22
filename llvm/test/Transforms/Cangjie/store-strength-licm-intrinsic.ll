; RUN: opt -S -passes='loop-simplify,lcssa,loop-mssa(licm)' < %s | FileCheck %s
; The existing direct-intrinsic LICM path must retain strength too.
define void @same(i1 %c, i32 %n, i8 addrspace(1)* %v, i8 addrspace(1)* %w, i8 addrspace(1)* addrspace(1)* %p, i8 addrspace(1)* %base) gc "cangjie" {
; CHECK-LABEL: define void @same(
; CHECK-NOT: call void {{.*}}@llvm.cj.gcwrite.ref(
; CHECK: exit:
; CHECK: @llvm.cj.gcwrite.ref({{.*}}i32 2)
entry:
  br label %loop
loop:
  %i = phi i32 [ 0, %entry ], [ %next, %latch ]
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %v, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %p, i32 2)
  br i1 %c, label %a, label %b
a:
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %v, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %p, i32 2)
  br label %latch
b:
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %w, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %p, i32 2)
  br label %latch
latch:
  %next = add i32 %i, 1
  %done = icmp eq i32 %next, %n
  br i1 %done, label %exit, label %loop
exit:
  ret void
}
define void @mixed(i1 %c, i32 %n, i8 addrspace(1)* %v, i8 addrspace(1)* %w, i8 addrspace(1)* addrspace(1)* %p, i8 addrspace(1)* %base) gc "cangjie" {
; CHECK-LABEL: define void @mixed(
; CHECK: a:
; CHECK: @llvm.cj.gcwrite.ref({{.*}}i32 2)
; CHECK: b:
; CHECK: @llvm.cj.gcwrite.ref({{.*}}i32 1)
; CHECK: exit:
; CHECK-NOT: call void {{.*}}@llvm.cj.gcwrite.ref(
entry:
  br label %loop
loop:
  %i = phi i32 [ 0, %entry ], [ %next, %latch ]
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %v, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %p, i32 2)
  br i1 %c, label %a, label %b
a:
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %v, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %p, i32 2)
  br label %latch
b:
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %w, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %p, i32 1)
  br label %latch
latch:
  %next = add i32 %i, 1
  %done = icmp eq i32 %next, %n
  br i1 %done, label %exit, label %loop
exit:
  ret void
}
define void @mixed_unknown(i1 %c, i32 %n, i8 addrspace(1)* %v, i8 addrspace(1)* %w, i8 addrspace(1)* addrspace(1)* %p, i8 addrspace(1)* %base) gc "cangjie" {
; CHECK-LABEL: define void @mixed_unknown(
; CHECK: a:
; CHECK: @llvm.cj.gcwrite.ref({{.*}}i32 2)
; CHECK: b:
; CHECK: @llvm.cj.gcwrite.ref({{.*}}%p)
; CHECK: exit:
; CHECK-NOT: call void {{.*}}@llvm.cj.gcwrite.ref(
entry:
  br label %loop
loop:
  %i = phi i32 [ 0, %entry ], [ %next, %latch ]
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %v, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %p, i32 2)
  br i1 %c, label %a, label %b
a:
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %v, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %p, i32 2)
  br label %latch
b:
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %w, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %p)
  br label %latch
latch:
  %next = add i32 %i, 1
  %done = icmp eq i32 %next, %n
  br i1 %done, label %exit, label %loop
exit:
  ret void
}

declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)
