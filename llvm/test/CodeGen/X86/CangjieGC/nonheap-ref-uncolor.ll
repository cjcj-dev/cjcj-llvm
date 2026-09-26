; RUN: llc --cangjie-pipeline -mtriple=x86_64 -print-after=cj-barrier-lowering \
; RUN:   -o /dev/null < %s 2>&1 | FileCheck %s

; zAddress.inline.hpp:609-614 uncolors only a load-good zpointer, by the
; published load shift. A value-struct field through an AS0 place is a raw
; LoadInst/StoreInst, not llvm.cj.gcread/gcwrite
; (CJBarrierLowering.cpp:1404-1406). STACK_ROOTS_STAY_PLAIN: the slot value
; and a function argument are already plain addresses. ptrmask on a GC
; pointer is rejected (CJIRVerifier.cpp:465). Shift uncolor of a plain
; address is rejected (CJIRVerifier.cpp:947). Lowering must leave the raw
; load/store untouched. Heap-place raw loads stay untouched.

%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }

define i8 @string_get(%"record.std.core:String"* %this, i64 %index) gc "cangjie" {
; CHECK-LABEL: define i8 @string_get(
; CHECK-NOT: llvm.ptrmask
; CHECK-NOT: @g_cjLoadShift
; CHECK: [[RAW:%.*]] = load i8 addrspace(1)*, i8 addrspace(1)**
; CHECK: getelementptr {{.*}} [[RAW]]
; CHECK-NOT: llvm.ptrmask
; CHECK-NOT: @g_cjLoadShift
; CHECK: ret i8
entry:
  %p = getelementptr inbounds %"record.std.core:String", %"record.std.core:String"* %this, i64 0, i32 0
  %raw = load i8 addrspace(1)*, i8 addrspace(1)** %p, align 8
  %payload = getelementptr i8, i8 addrspace(1)* %raw, i64 16
  %slot = getelementptr i8, i8 addrspace(1)* %payload, i64 %index
  %b = load i8, i8 addrspace(1)* %slot, align 1
  ret i8 %b
}

define void @string_rawdata(%"record.std.core:String"* %this,
                           i8 addrspace(1)** %dst) gc "cangjie" {
; CHECK-LABEL: define void @string_rawdata(
; CHECK-NOT: llvm.ptrmask
; CHECK-NOT: @g_cjLoadShift
; CHECK: [[RAW:%.*]] = load i8 addrspace(1)*, i8 addrspace(1)**
; CHECK-NOT: llvm.ptrmask
; CHECK: store i8 addrspace(1)* [[RAW]], i8 addrspace(1)** %dst
entry:
  %p = getelementptr inbounds %"record.std.core:String", %"record.std.core:String"* %this, i64 0, i32 0
  %raw = load i8 addrspace(1)*, i8 addrspace(1)** %p, align 8
  store i8 addrspace(1)* %raw, i8 addrspace(1)** %dst, align 8
  ret void
}

define void @store_into_stack(i8 addrspace(1)* %val,
                              %"record.std.core:String"* %this) gc "cangjie" {
; CHECK-LABEL: define void @store_into_stack(
; CHECK-NOT: llvm.ptrmask
; CHECK-NOT: @g_cjLoadShift
; CHECK: store i8 addrspace(1)* %val
entry:
  %p = getelementptr inbounds %"record.std.core:String", %"record.std.core:String"* %this, i64 0, i32 0
  store i8 addrspace(1)* %val, i8 addrspace(1)** %p, align 8
  ret void
}

define i8 addrspace(1)* @heap_place_untouched(i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
; CHECK-LABEL: define i8 addrspace(1)* @heap_place_untouched(
; CHECK-NOT: llvm.ptrmask
; CHECK-NOT: @g_cjLoadShift
; CHECK: [[V:%.*]] = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %field
; CHECK-NEXT: ret i8 addrspace(1)* [[V]]
entry:
  %v = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %field, align 8
  ret i8 addrspace(1)* %v
}
