; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O0 -verify-machineinstrs -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 -verify-machineinstrs -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
;
; A GEP without inbounds proves the domain only for a constant offset in
; [0, size) of a proven MCC_NewObject start. Everything else keeps the
; reserved-range test and its accessor fallback.
target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"

; CHECK-LABEL: define i8 addrspace(1)* @object_end(
; CHECK: load i64, i64* @g_cjHeapRangeCount
; CHECK: CJ_MCC_ReadRefField
define i8 addrspace(1)* @object_end(i8* %type) gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i32)* @CJ_MCC_NewObject, i32 2, i32 0, i8* %type, i32 32)
  %heap = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  %field = getelementptr i8, i8 addrspace(1)* %heap, i64 32
  %slot = bitcast i8 addrspace(1)* %field to i8 addrspace(1)* addrspace(1)*
  %value = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %heap, i8 addrspace(1)* addrspace(1)* %slot)
  ret i8 addrspace(1)* %value
}

; CHECK-LABEL: define i8 addrspace(1)* @negative_offset(
; CHECK: load i64, i64* @g_cjHeapRangeCount
define i8 addrspace(1)* @negative_offset(i8* %type) gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i32)* @CJ_MCC_NewObject, i32 2, i32 0, i8* %type, i32 32)
  %heap = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  %field = getelementptr i8, i8 addrspace(1)* %heap, i64 -8
  %slot = bitcast i8 addrspace(1)* %field to i8 addrspace(1)* addrspace(1)*
  %value = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %heap, i8 addrspace(1)* addrspace(1)* %slot)
  ret i8 addrspace(1)* %value
}

; CHECK-LABEL: define i8 addrspace(1)* @variable_offset(
; CHECK: load i64, i64* @g_cjHeapRangeCount
define i8 addrspace(1)* @variable_offset(i8* %type, i64 %index) gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i32)* @CJ_MCC_NewObject, i32 2, i32 0, i8* %type, i32 32)
  %heap = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  %field = getelementptr i8, i8 addrspace(1)* %heap, i64 %index
  %slot = bitcast i8 addrspace(1)* %field to i8 addrspace(1)* addrspace(1)*
  %value = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %heap, i8 addrspace(1)* addrspace(1)* %slot)
  ret i8 addrspace(1)* %value
}

; CHECK-LABEL: define i8 addrspace(1)* @dynamic_size(
; CHECK: load i64, i64* @g_cjHeapRangeCount
define i8 addrspace(1)* @dynamic_size(i8* %type, i32 %size) gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i32)* @CJ_MCC_NewObject, i32 2, i32 0, i8* %type, i32 %size)
  %heap = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  %field = getelementptr i8, i8 addrspace(1)* %heap, i64 8
  %slot = bitcast i8 addrspace(1)* %field to i8 addrspace(1)* addrspace(1)*
  %value = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %heap, i8 addrspace(1)* addrspace(1)* %slot)
  ret i8 addrspace(1)* %value
}

; Arrays have no object size operand here; only inbounds GEPs prove them.
; CHECK-LABEL: define i8 addrspace(1)* @array_field(
; CHECK: load i64, i64* @g_cjHeapRangeCount
define i8 addrspace(1)* @array_field(i8* %type) gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i64, i64)* @CJ_MCC_NewArray, i32 3, i32 0, i8* %type, i64 8, i64 64)
  %heap = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  %field = getelementptr i8, i8 addrspace(1)* %heap, i64 8
  %slot = bitcast i8 addrspace(1)* %field to i8 addrspace(1)* addrspace(1)*
  %value = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %heap, i8 addrspace(1)* addrspace(1)* %slot)
  ret i8 addrspace(1)* %value
}

; A receiver or other unknown AS1 argument may be a stack object or value
; storage (interprocedural escape analysis). It is not proven.
; CHECK-LABEL: define i8 addrspace(1)* @receiver_field(
; CHECK: load i64, i64* @g_cjHeapRangeCount
; CHECK: CJ_MCC_ReadRefField
define i8 addrspace(1)* @receiver_field(i8 addrspace(1)* %this) gc "cangjie" {
entry:
  %field = getelementptr i8, i8 addrspace(1)* %this, i64 8
  %slot = bitcast i8 addrspace(1)* %field to i8 addrspace(1)* addrspace(1)*
  %value = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %this, i8 addrspace(1)* addrspace(1)* %slot)
  ret i8 addrspace(1)* %value
}

; CHECK-LABEL: define void @stack_field_write(
; CHECK: load i64, i64* @g_cjHeapRangeCount
define void @stack_field_write(i8 addrspace(1)* %value) gc "cangjie" {
entry:
  %storage = alloca [32 x i8], align 8
  %bytes = bitcast [32 x i8]* %storage to i8*
  %stack = addrspacecast i8* %bytes to i8 addrspace(1)*
  %field = getelementptr i8, i8 addrspace(1)* %stack, i64 8
  %slot = bitcast i8 addrspace(1)* %field to i8 addrspace(1)* addrspace(1)*
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %stack, i8 addrspace(1)* addrspace(1)* %slot, i32 1)
  ret void
}

; CHECK-LABEL: define i8 addrspace(1)* @mixed_phi(
; CHECK: load i64, i64* @g_cjHeapRangeCount
define i8 addrspace(1)* @mixed_phi(i8* %type, i8 addrspace(1)* %arg, i1 %cond) gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i32)* @CJ_MCC_NewObject, i32 2, i32 0, i8* %type, i32 32)
  %heap = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  br i1 %cond, label %left, label %join
left:
  br label %join
join:
  %merged = phi i8 addrspace(1)* [ %heap, %left ], [ %arg, %entry ]
  %field = getelementptr i8, i8 addrspace(1)* %merged, i64 8
  %slot = bitcast i8 addrspace(1)* %field to i8 addrspace(1)* addrspace(1)*
  %value = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %merged, i8 addrspace(1)* addrspace(1)* %slot)
  ret i8 addrspace(1)* %value
}

declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare i8 addrspace(1)* @CJ_MCC_NewArray(i8*, i64, i64)
declare token @llvm.cj.gc.statepoint(...)
declare i8 addrspace(1)* @llvm.cj.gc.result(token)
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)
declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
