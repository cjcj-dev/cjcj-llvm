; RUN: opt -S -cj-rewrite-statepoint %s | FileCheck %s
; RUN: opt -S -passes=cj-rewrite-statepoint %s | FileCheck %s
;
; Call-free managed functions keep the same metadata contract as callers.
; CHECK-NOT: "leaf-function"
; CHECK-LABEL: define i64 @leaf(
; CHECK: ret i64 %value
; CHECK-NOT: "leaf-function"
define i64 @leaf(i64 %value) gc "cangjie" {
  ret i64 %value
}
