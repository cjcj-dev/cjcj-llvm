; RUN: opt -passes=cj-rewrite-statepoint -S < %s | FileCheck %s

target datalayout = "e-p:64:64-p1:64:64"

%S = type { i8 addrspace(1)*, i64 }

declare void @may_gc() gc "cangjie"

; The forwarded Argument is not registered again in the callee frame.
; CHECK-LABEL: define i8 addrspace(1)* @leaf
; CHECK: call token (...) @llvm.cj.gc.statepoint{{.*}}@may_gc
; CHECK-NOT: "struct-live"(%S* %arg)
; CHECK: ret i8 addrspace(1)*
define i8 addrspace(1)* @leaf(%S* noalias %arg) gc "cangjie" {
entry:
  call void @may_gc()
  %field = getelementptr inbounds %S, %S* %arg, i32 0, i32 0
  %value = load i8 addrspace(1)*, i8 addrspace(1)** %field
  ret i8 addrspace(1)* %value
}

; CHECK-LABEL: define i8 addrspace(1)* @forward2
; CHECK: call token (...) @llvm.cj.gc.statepoint{{.*}}@leaf
; CHECK-NOT: "struct-live"(%S* %arg)
; CHECK: ret i8 addrspace(1)*
define i8 addrspace(1)* @forward2(%S* noalias %arg) gc "cangjie" {
entry:
  %value = call i8 addrspace(1)* @leaf(%S* %arg)
  ret i8 addrspace(1)* %value
}

; CHECK-LABEL: define i8 addrspace(1)* @forward1
; CHECK: call token (...) @llvm.cj.gc.statepoint{{.*}}@forward2
; CHECK-NOT: "struct-live"(%S* %arg)
; CHECK: ret i8 addrspace(1)*
define i8 addrspace(1)* @forward1(%S* noalias %arg) gc "cangjie" {
entry:
  %value = call i8 addrspace(1)* @forward2(%S* %arg)
  ret i8 addrspace(1)* %value
}

; The physical owner is registered at the outermost covering call even though
; the slot has no use after that call.
; CHECK-LABEL: define i8 addrspace(1)* @origin
; CHECK: call token (...) @llvm.cj.gc.statepoint{{.*}}@forward1{{.*}}[ "struct-live"(%S* %slot) ]
define i8 addrspace(1)* @origin(i8 addrspace(1)* %input) gc "cangjie" {
entry:
  %slot = alloca %S, align 8
  %field = getelementptr inbounds %S, %S* %slot, i32 0, i32 0
  store i8 addrspace(1)* %input, i8 addrspace(1)** %field
  %value = call i8 addrspace(1)* @forward1(%S* %slot)
  ret i8 addrspace(1)* %value
}
