; RUN: opt -S -cangjie-pipeline -passes='function(loop-mssa(licm))' %s | FileCheck %s
; RUN: opt -opaque-pointers -S -cangjie-pipeline -passes='function(loop-mssa(licm))' %s | FileCheck %s
; Both ref-read intrinsics return the reference stored in the slot. Its type,
; not the slot pointer's pointee API, supplies the access size in either mode.
target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
declare i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)**) nounwind
declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*) nounwind

; CHECK-LABEL: define {{.*}} @static_unknown_extent(
; CHECK: entry:
; CHECK-NOT: call {{.*}} @llvm.cj.gcread.static.ref(
; CHECK: read:
; CHECK: %value = call {{.*}} @llvm.cj.gcread.static.ref(
define i8 addrspace(1)* @static_unknown_extent(i8 addrspace(1)* %owner, i8 addrspace(1)** %slot, i1 %run, i64 %count) {
entry:
  br label %loop
loop:
  %i = phi i64 [0, %entry], [%next, %latch]
  %last = phi i8 addrspace(1)* [null, %entry], [%result, %latch]
  br i1 %run, label %read, label %latch
read:
  %value = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** %slot)
  br label %latch
latch:
  %result = phi i8 addrspace(1)* [%last, %loop], [%value, %read]
  %next = add i64 %i, 1
  %more = icmp ult i64 %next, %count
  br i1 %more, label %loop, label %exit
exit:
  ret i8 addrspace(1)* %result
}

; CHECK-LABEL: define {{.*}} @static_in_range(
; CHECK: entry:
; CHECK: %value = call {{.*}} @llvm.cj.gcread.static.ref(
; CHECK: br label %loop
define i8 addrspace(1)* @static_in_range(i8 addrspace(1)* %owner, i8 addrspace(1)** align 8 dereferenceable(8) %slot, i1 %run, i64 %count) {
entry:
  br label %loop
loop:
  %i = phi i64 [0, %entry], [%next, %latch]
  %last = phi i8 addrspace(1)* [null, %entry], [%result, %latch]
  br i1 %run, label %read, label %latch
read:
  %value = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** %slot)
  br label %latch
latch:
  %result = phi i8 addrspace(1)* [%last, %loop], [%value, %read]
  %next = add i64 %i, 1
  %more = icmp ult i64 %next, %count
  br i1 %more, label %loop, label %exit
exit:
  ret i8 addrspace(1)* %result
}

; CHECK-LABEL: define {{.*}} @instance_unknown_extent(
; CHECK: entry:
; CHECK-NOT: call {{.*}} @llvm.cj.gcread.ref(
; CHECK: read:
; CHECK: %value = call {{.*}} @llvm.cj.gcread.ref(
define i8 addrspace(1)* @instance_unknown_extent(i8 addrspace(1)* %owner, i8 addrspace(1)* addrspace(1)* %slot, i1 %run, i64 %count) {
entry:
  br label %loop
loop:
  %i = phi i64 [0, %entry], [%next, %latch]
  %last = phi i8 addrspace(1)* [null, %entry], [%result, %latch]
  br i1 %run, label %read, label %latch
read:
  %value = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %owner, i8 addrspace(1)* addrspace(1)* %slot)
  br label %latch
latch:
  %result = phi i8 addrspace(1)* [%last, %loop], [%value, %read]
  %next = add i64 %i, 1
  %more = icmp ult i64 %next, %count
  br i1 %more, label %loop, label %exit
exit:
  ret i8 addrspace(1)* %result
}

; CHECK-LABEL: define {{.*}} @instance_in_range(
; CHECK: entry:
; CHECK: %value = call {{.*}} @llvm.cj.gcread.ref(
; CHECK: br label %loop
define i8 addrspace(1)* @instance_in_range(i8 addrspace(1)* %owner, i8 addrspace(1)* addrspace(1)* align 8 dereferenceable(8) %slot, i1 %run, i64 %count) {
entry:
  br label %loop
loop:
  %i = phi i64 [0, %entry], [%next, %latch]
  %last = phi i8 addrspace(1)* [null, %entry], [%result, %latch]
  br i1 %run, label %read, label %latch
read:
  %value = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %owner, i8 addrspace(1)* addrspace(1)* %slot)
  br label %latch
latch:
  %result = phi i8 addrspace(1)* [%last, %loop], [%value, %read]
  %next = add i64 %i, 1
  %more = icmp ult i64 %next, %count
  br i1 %more, label %loop, label %exit
exit:
  ret i8 addrspace(1)* %result
}
