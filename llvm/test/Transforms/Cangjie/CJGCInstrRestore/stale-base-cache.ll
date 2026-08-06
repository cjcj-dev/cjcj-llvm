; RUN: opt -passes='cj-gcinstr-restore,verify' -S %s | FileCheck %s

target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

define void @stale_base_cache() gc "cangjie" {
entry:
  switch i32 0, label %exit [
    i32 0, label %second.pre
  ]

exit:
  ret void

first.pre:
  br label %first.loop

first.loop:
  %first.data = phi i8* addrspace(1)* [ null, %first.pre ], [ %first.next, %first.latch ]
  %first.slot = bitcast i8* addrspace(1)* %first.data to i8 addrspace(1)* addrspace(1)*
  %first.ref = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %first.slot, align 8
  br label %first.latch

first.latch:
  %first.next = load i8* addrspace(1)*, i8* addrspace(1)* addrspace(1)* null, align 8
  br i1 false, label %first.loop, label %exit

second.pre:
  %unrelated.ref = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* null, align 8
  %second.init.slot = bitcast i8 addrspace(1)* null to i8* addrspace(1)* addrspace(1)*
  %second.init = load i8* addrspace(1)*, i8* addrspace(1)* addrspace(1)* %second.init.slot, align 8
  br i1 false, label %second.ph, label %exit

second.ph:
  br label %second.loop

second.loop:
  %second.data = phi i8* addrspace(1)* [ %second.init, %second.ph ], [ null, %second.latch ]
  %second.slot = bitcast i8* addrspace(1)* %second.data to i8 addrspace(1)* addrspace(1)*
  %second.ref = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %second.slot, align 8
  br label %second.latch

second.latch:
  br i1 false, label %second.loop, label %exit
}

; CHECK-LABEL: define void @stale_base_cache()
; CHECK: call i8 addrspace(1)* @llvm.cj.gcread.ref
; CHECK-LABEL: second.loop:
; CHECK: phi i8 addrspace(1)*
