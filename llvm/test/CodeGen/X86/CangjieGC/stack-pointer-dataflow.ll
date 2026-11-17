; RUN: llc --cangjie-pipeline -cj-stack-grow=false -O0 -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs \
; RUN:   -stop-after=cangjie-stack-pointer-inserter -o - < %s | FileCheck %s --check-prefixes=CHECK,O0
; RUN: llc --cangjie-pipeline -cj-stack-grow=true -O0 -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs \
; RUN:   -stop-after=cangjie-stack-pointer-inserter -o - < %s | FileCheck %s --check-prefixes=CHECK,O0
; RUN: llc --cangjie-pipeline -cj-stack-grow=false -O2 -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs \
; RUN:   -stop-after=cangjie-stack-pointer-inserter -o - < %s | FileCheck %s --check-prefixes=CHECK,O2
; RUN: llc --cangjie-pipeline -cj-stack-grow=true -O2 -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs \
; RUN:   -stop-after=cangjie-stack-pointer-inserter -o - < %s | FileCheck %s --check-prefixes=CHECK,O2
; RUN: llc --cangjie-pipeline -cj-stack-grow=false -O0 -mtriple=aarch64-unknown-linux-gnu -verify-machineinstrs \
; RUN:   -stop-after=cangjie-stack-pointer-inserter -o - < %s | FileCheck %s --check-prefixes=CHECK,O0
; RUN: llc --cangjie-pipeline -cj-stack-grow=true -O0 -mtriple=aarch64-unknown-linux-gnu -verify-machineinstrs \
; RUN:   -stop-after=cangjie-stack-pointer-inserter -o - < %s | FileCheck %s --check-prefixes=CHECK,O0
; RUN: llc --cangjie-pipeline -cj-stack-grow=false -O2 -mtriple=aarch64-unknown-linux-gnu -verify-machineinstrs \
; RUN:   -stop-after=cangjie-stack-pointer-inserter -o - < %s | FileCheck %s --check-prefixes=CHECK,O2
; RUN: llc --cangjie-pipeline -cj-stack-grow=true -O2 -mtriple=aarch64-unknown-linux-gnu -verify-machineinstrs \
; RUN:   -stop-after=cangjie-stack-pointer-inserter -o - < %s | FileCheck %s --check-prefixes=CHECK,O2
;
; Cached dataflow inputs must preserve the roots at each statepoint.
; A slot can be live at one statepoint and dead at the next in the same block.
; Keep the successor contribution across a loop, the empty set, and the
; existing gc-safepoint exclusion independent of the suffix queries.
;
; CHECK-LABEL: name: live_then_dead
; CHECK: STATEPOINT 1,{{.*}} 2, 1, 1, 8, %stack.0.slot, 0, csr
; O0: STATEPOINT 2,{{.*}} 2, 1, 1, 8, %stack.1, 0, csr
; O2: STATEPOINT 2,{{.*}} 2, 1, ${{(rbx|x19)}}, csr
; CHECK-LABEL: name: successor_live
; CHECK: STATEPOINT 3,{{.*}} 2, 1, 1, 8, %stack.0.slot, 0, csr
; CHECK-LABEL: name: empty_slots
; CHECK: STATEPOINT 4,{{.*}} 2, 0, csr
; CHECK: STATEPOINT 5,{{.*}} 2, 0, csr
; CHECK-LABEL: name: poll_then_live
; CHECK: STATEPOINT 6,{{.*}} 2, 0, csr
; CHECK: STATEPOINT 7,{{.*}} 2, 1, 1, 8, %stack.0.slot, 0, csr
;
; EMPTY-LABEL: name: empty_slots
; EMPTY: STATEPOINT 4,{{.*}} 2, 0, csr
; EMPTY: STATEPOINT 5,{{.*}} 2, 0, csr

declare token @llvm.cj.gc.statepoint(...)
declare void @safepoint()
declare void @poll() "gc-safepoint"

define i8* @live_then_dead(i8* %p) gc "cangjie" {
entry:
  %slot = alloca i8*, align 8
  store volatile i8* %p, i8** %slot, align 8
  %first = call token (...) @llvm.cj.gc.statepoint(i64 1, i32 0, void ()* @safepoint, i32 0, i32 0)
  %value = load volatile i8*, i8** %slot, align 8
  %second = call token (...) @llvm.cj.gc.statepoint(i64 2, i32 0, void ()* @safepoint, i32 0, i32 0)
  ret i8* %value
}

define i8* @successor_live(i8* %p, i1 %again) gc "cangjie" {
entry:
  %slot = alloca i8*, align 8
  store volatile i8* %p, i8** %slot, align 8
  br label %loop
loop:
  %first = call token (...) @llvm.cj.gc.statepoint(i64 3, i32 0, void ()* @safepoint, i32 0, i32 0)
  br i1 %again, label %loop, label %exit
exit:
  %value = load volatile i8*, i8** %slot, align 8
  ret i8* %value
}

define void @empty_slots() gc "cangjie" {
entry:
  %first = call token (...) @llvm.cj.gc.statepoint(i64 4, i32 0, void ()* @safepoint, i32 0, i32 0)
  %second = call token (...) @llvm.cj.gc.statepoint(i64 5, i32 0, void ()* @safepoint, i32 0, i32 0)
  ret void
}

define i8* @poll_then_live(i8* %p) gc "cangjie" {
entry:
  %slot = alloca i8*, align 8
  store volatile i8* %p, i8** %slot, align 8
  %poll = call token (...) @llvm.cj.gc.statepoint(i64 6, i32 0, void ()* @poll, i32 0, i32 0)
  %live = call token (...) @llvm.cj.gc.statepoint(i64 7, i32 0, void ()* @safepoint, i32 0, i32 0)
  %value = load volatile i8*, i8** %slot, align 8
  ret i8* %value
}

; The second pointer first reaches the loop through its backedge. A changed
; input must trigger another transfer even after the first visit is cached.
; CHECK-LABEL: name: backedge_new_pointer
; CHECK: STATEPOINT 8,{{.*}}%stack.0.first_slot, 0{{.*}}%stack.1.second_slot, 0

define i8* @backedge_new_pointer(i8* %p, i8* %q, i1 %again) gc "cangjie" {
entry:
  %first_slot = alloca i8*, align 8
  %second_slot = alloca i8*, align 8
  store volatile i8* %p, i8** %first_slot, align 8
  store volatile i8* null, i8** %second_slot, align 8
  br label %loop
loop:
  %point = call token (...) @llvm.cj.gc.statepoint(i64 8, i32 0, void ()* @safepoint, i32 0, i32 0)
  br i1 %again, label %backedge, label %exit
backedge:
  store volatile i8* %q, i8** %second_slot, align 8
  br label %loop
exit:
  %first = load volatile i8*, i8** %first_slot, align 8
  %second = load volatile i8*, i8** %second_slot, align 8
  ret i8* %second
}
