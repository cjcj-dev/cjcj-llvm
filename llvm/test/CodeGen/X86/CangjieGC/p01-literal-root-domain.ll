; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu < %s | FileCheck %s
; Immutable literals remain emitted data, while mutable oop slots remain GC roots.
target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
%Record = type { i8 addrspace(1)*, i32, i32 }
@plain_literal = constant %Record zeroinitializer #0
@mutable_root = global i8 addrspace(1)* null #0
attributes #0 = { "CJGlobalValue" }
; CHECK: plain_literal:
; CHECK: .section .cjmetadata.gcroots,"aw",@progbits
; CHECK-NOT: .quad .LRef.plain_literal
; CHECK: .quad .LRef.mutable_root
; CHECK-NOT: .quad .LRef.plain_literal
