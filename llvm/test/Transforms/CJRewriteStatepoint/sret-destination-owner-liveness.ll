; RUN: opt -passes=cj-rewrite-statepoint -S < %s | FileCheck %s

target datalayout = "e-p:64:64-p1:64:64"

%S = type { i8 addrspace(1)*, i64 }

define void @fill(%S* noalias sret(%S) %result,
                  i8 addrspace(1)* %input) gc "cangjie" {
entry:
  %field = getelementptr inbounds %S, %S* %result, i32 0, i32 0
  store i8 addrspace(1)* %input, i8 addrspace(1)** %field
  ret void
}

; The caller owns the physical result slot.  Its use after the call keeps that
; slot enumerable at the statepoint while the callee writes through sret.
; CHECK-LABEL: define i8 addrspace(1)* @caller
; CHECK: call token (...) @llvm.cj.gc.statepoint{{.*}}@fill{{.*}}[ "struct-live"(%S* %result) ]
define i8 addrspace(1)* @caller(i8 addrspace(1)* %input) gc "cangjie" {
entry:
  %result = alloca %S, align 8
  call void @fill(%S* sret(%S) %result, i8 addrspace(1)* %input)
  %field = getelementptr inbounds %S, %S* %result, i32 0, i32 0
  %value = load i8 addrspace(1)*, i8 addrspace(1)** %field
  ret i8 addrspace(1)* %value
}
