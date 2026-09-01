; RUN: opt -passes=cj-rewrite-statepoint -S < %s | FileCheck %s

target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"

%Inner = type { i8 addrspace(1)*, i8 addrspace(1)* }
%Outer = type { i64, %Inner }

declare void @safepoint()

; The live address is the GC slot nested inside %Outer, not a top-level field.
; CHECK-LABEL: define i8 addrspace(1)* @nested_struct_gc_slot
; CHECK: call token (...) @llvm.cj.gc.statepoint{{.*}}@safepoint{{.*}}[ "struct-live"(i8* %field) ]
define i8 addrspace(1)* @nested_struct_gc_slot() gc "cangjie" {
entry:
  %outer = alloca %Outer, align 8
  %gc.slot = getelementptr inbounds %Outer, %Outer* %outer, i64 0, i32 1, i32 1
  call void @safepoint()
  %value = load i8 addrspace(1)*, i8 addrspace(1)** %gc.slot, align 8
  ret i8 addrspace(1)* %value
}
