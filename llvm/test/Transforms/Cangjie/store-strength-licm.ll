; RUN: opt -S -passes='loop-simplify,lcssa,loop-mssa(licm)' < %s | FileCheck %s
; Loop promotion must retain a uniform store decorator, and must not promote
; mixed-strength stores into an arbitrarily decorated exit store.
define void @same(i1 %c, i32 %n, i8 addrspace(1)* %v, i8 addrspace(1)* %w, i8 addrspace(1)* addrspace(1)* %p) {
; CHECK-LABEL: define void @same(
; CHECK-NOT: store
; CHECK: exit:
; CHECK: store cj_strength(2)
entry:
  br label %loop
loop:
  %i = phi i32 [ 0, %entry ], [ %next, %latch ]
  store cj_strength(2) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p
  br i1 %c, label %a, label %b
a:
  store cj_strength(2) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p
  br label %latch
b:
  store cj_strength(2) i8 addrspace(1)* %w, i8 addrspace(1)* addrspace(1)* %p
  br label %latch
latch:
  %next = add i32 %i, 1
  %done = icmp eq i32 %next, %n
  br i1 %done, label %exit, label %loop
exit:
  ret void
}
define void @mixed(i1 %c, i32 %n, i8 addrspace(1)* %v, i8 addrspace(1)* %w, i8 addrspace(1)* addrspace(1)* %p) {
; CHECK-LABEL: define void @mixed(
; CHECK: a:
; CHECK: store cj_strength(2)
; CHECK: b:
; CHECK: store cj_strength(1)
; CHECK: exit:
; CHECK-NOT: store
entry:
  br label %loop
loop:
  %i = phi i32 [ 0, %entry ], [ %next, %latch ]
  store cj_strength(2) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p
  br i1 %c, label %a, label %b
a:
  store cj_strength(2) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p
  br label %latch
b:
  store cj_strength(1) i8 addrspace(1)* %w, i8 addrspace(1)* addrspace(1)* %p
  br label %latch
latch:
  %next = add i32 %i, 1
  %done = icmp eq i32 %next, %n
  br i1 %done, label %exit, label %loop
exit:
  ret void
}
define void @mixed_unknown(i1 %c, i32 %n, i8 addrspace(1)* %v, i8 addrspace(1)* %w, i8 addrspace(1)* addrspace(1)* %p) {
; CHECK-LABEL: define void @mixed_unknown(
; CHECK: a:
; CHECK: store cj_strength(2)
; CHECK: b:
; CHECK: store i8 addrspace(1)*
; CHECK: exit:
; CHECK-NOT: store
entry:
  br label %loop
loop:
  %i = phi i32 [ 0, %entry ], [ %next, %latch ]
  store cj_strength(2) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p
  br i1 %c, label %a, label %b
a:
  store cj_strength(2) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p
  br label %latch
b:
  store i8 addrspace(1)* %w, i8 addrspace(1)* addrspace(1)* %p
  br label %latch
latch:
  %next = add i32 %i, 1
  %done = icmp eq i32 %next, %n
  br i1 %done, label %exit, label %loop
exit:
  ret void
}
