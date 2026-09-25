; RUN: llc --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu < %s | FileCheck %s
; REQUIRES: aarch64-registered-target
;
; AArch64AsmPrinter.cpp:1718-1725 lowers TCRETURNdi to B before the streamer.
; emitMccNewObjectFastPath runs first (AArch64AsmPrinter.cpp:1548). A tail call
; must take that same B lowering and must not enter the fast path: TCRETURNdi
; has no AsmString (AArch64InstrFormats.td:84-91) and no caller epilogue.

; CHECK-LABEL: allocate_tail:
; CHECK-NOT: NewObjFastPath
; CHECK-NOT: bl{{[[:space:]]+}}CJ_MCC_NewObject
; CHECK: {{^[[:space:]]*b[[:space:]]+CJ_MCC_NewObject$}}
; CHECK-NOT: NewObjFastPath
; CHECK-NOT: bl{{[[:space:]]+}}CJ_MCC_NewObject

; CHECK-LABEL: allocate_finalizer_tail:
; CHECK-NOT: NewObjFastPath
; CHECK-NOT: NewObjSlowPath
; CHECK-NOT: bl{{[[:space:]]+}}CJ_MCC_NewFinalizer
; CHECK: {{^[[:space:]]*b[[:space:]]+CJ_MCC_NewFinalizer$}}
; CHECK-NOT: NewObjFastPath
; CHECK-NOT: bl{{[[:space:]]+}}CJ_MCC_NewFinalizer

; CHECK-LABEL: allocate_object:
; CHECK: NewObjFastPath
; CHECK: bl{{[[:space:]]+}}CJ_MCC_NewObject

; CHECK-LABEL: allocate_finalizer:
; CHECK: NewObjFastPath
; CHECK: bl{{[[:space:]]+}}CJ_MCC_NewFinalizer

target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"

define i8 addrspace(1)* @allocate_tail(i8* %type, i32 %size) gc "cangjie" {
  %p = tail call i8 addrspace(1)* @CJ_MCC_NewObject(i8* %type, i32 %size)
  ret i8 addrspace(1)* %p
}

define i8 addrspace(1)* @allocate_finalizer_tail(i8* %type, i32 %size) gc "cangjie" {
  %p = tail call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* %type, i32 %size)
  ret i8 addrspace(1)* %p
}

define i8 addrspace(1)* @allocate_object(i8* %type, i32 %size) gc "cangjie" {
  %p = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* %type, i32 %size)
  ret i8 addrspace(1)* %p
}

define i8 addrspace(1)* @allocate_finalizer(i8* %type, i32 %size) gc "cangjie" {
  %p = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* %type, i32 %size)
  ret i8 addrspace(1)* %p
}

declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8*, i32)
declare void @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)*)
