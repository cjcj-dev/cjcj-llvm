; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu < %s | FileCheck %s

target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"

%Nested = type { i32, [2 x i8 addrspace(1)*], i8* }

@top_array = global [2 x i8 addrspace(1)*] zeroinitializer #0
@nested_array = global %Nested zeroinitializer #0

attributes #0 = { "CJGlobalValue" }

; CHECK:      .section .cjmetadata.gcroots,"aw",@progbits
; CHECK:      .quad .LRef.top_array+0
; CHECK-NEXT: .quad .LRef.top_array+8
; CHECK-NEXT: .quad .LRef.nested_array+8
; CHECK-NEXT: .quad .LRef.nested_array+16
; CHECK-NOT:  .quad .LRef.nested_array+24
