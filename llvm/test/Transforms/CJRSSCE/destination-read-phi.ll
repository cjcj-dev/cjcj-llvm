; RUN: opt -opaque-pointers=0 -passes=verify -disable-output < %s
; RUN: opt -opaque-pointers=0 -passes=cj-rssce -S < %s | FileCheck %s
; RUN: opt -opaque-pointers=0 -passes=cj-rssce -S < %s -o %t.opt.ll
; RUN: cat %t.opt.ll %S/Inputs/destination-read-phi-values.ll > %t.values.ll
; RUN: lli -opaque-pointers=0 -force-interpreter %t.values.ll
;
; Real load snapshots across a MemoryPhi, including an aliasing write on just
; one incoming edge. No function-level readonly: exercise destination reuse.
target datalayout = "e-p:64:64-i64:64-n8:16:32:64-S128"
%W = type { i64 }
define internal i64 @first(%W* nocapture readonly %p) #0 {
  %q = getelementptr inbounds %W, %W* %p, i64 0, i32 0
  %v = load i64, i64* %q, align 8
  ret i64 %v
}

; CHECK-LABEL: define i64 @read_across_phi(
; CHECK: %r = call i64 @first(%W* %late)
define i64 @read_across_phi(i1 %change) {
entry:
  %src = alloca %W, align 8
  %early = alloca %W, align 8
  %late = alloca %W, align 8
  %other = alloca i64, align 8
  %s = getelementptr inbounds %W, %W* %src, i64 0, i32 0
  %e = getelementptr inbounds %W, %W* %early, i64 0, i32 0
  %l = getelementptr inbounds %W, %W* %late, i64 0, i32 0
  store i64 1, i64* %s, align 8
  %old = load i64, i64* %s, align 8
  br i1 %change, label %write, label %merge
write:
  store i64 2, i64* %s, align 8
  br label %merge
merge:
  store i64 %old, i64* %e, align 8
  %new = load i64, i64* %s, align 8
  store i64 %new, i64* %l, align 8
  %r = call i64 @first(%W* %late)
  ret i64 %r
}

; CHECK-LABEL: define i64 @read_across_phi_no_write(
; CHECK: %r = call i64 @first(%W* %early)
define i64 @read_across_phi_no_write(i1 %change) {
entry:
  %src = alloca %W, align 8
  %early = alloca %W, align 8
  %late = alloca %W, align 8
  %other = alloca i64, align 8
  %s = getelementptr inbounds %W, %W* %src, i64 0, i32 0
  %e = getelementptr inbounds %W, %W* %early, i64 0, i32 0
  %l = getelementptr inbounds %W, %W* %late, i64 0, i32 0
  store i64 1, i64* %s, align 8
  %old = load i64, i64* %s, align 8
  br i1 %change, label %write, label %merge
write:
  store i64 2, i64* %other, align 8
  br label %merge
merge:
  store i64 %old, i64* %e, align 8
  %new = load i64, i64* %s, align 8
  store i64 %new, i64* %l, align 8
  %r = call i64 @first(%W* %late)
  ret i64 %r
}

; CHECK-LABEL: define i64 @same_snapshot_across_phi(
; CHECK: %r = call i64 @first(%W* %early)
define i64 @same_snapshot_across_phi(i1 %change) {
entry:
  %src = alloca %W, align 8
  %early = alloca %W, align 8
  %late = alloca %W, align 8
  %other = alloca i64, align 8
  %s = getelementptr inbounds %W, %W* %src, i64 0, i32 0
  %e = getelementptr inbounds %W, %W* %early, i64 0, i32 0
  %l = getelementptr inbounds %W, %W* %late, i64 0, i32 0
  store i64 1, i64* %s, align 8
  %old = load i64, i64* %s, align 8
  br i1 %change, label %write, label %merge
write:
  store i64 2, i64* %s, align 8
  br label %merge
merge:
  store i64 %old, i64* %e, align 8
  %new = load i64, i64* %s, align 8
  store i64 %old, i64* %l, align 8
  %r = call i64 @first(%W* %late)
  ret i64 %r
}

attributes #0 = { alwaysinline argmemonly nounwind willreturn }
