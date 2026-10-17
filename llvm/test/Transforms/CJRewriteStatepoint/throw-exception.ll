; RUN: opt < %s -S -passes=cj-rewrite-statepoint,verify | FileCheck %s

declare void @CJ_MCC_ThrowException(i8 addrspace(1)*)
declare void @foo()
declare void @take(void (i8 addrspace(1)*)*)
declare i32* @fake_personality_function()
declare token @llvm.cj.gc.statepoint(...)

define i8 addrspace(1)* @direct_throw(i8 addrspace(1)* %obj) gc "cangjie" {
; CHECK-LABEL: @direct_throw(
; CHECK: call token ({{.*}}) @llvm.cj.gc.statepoint{{.*}}@CJ_MCC_ThrowException{{.*}} [ "gc-live"(i8 addrspace(1)* %obj)
; CHECK-NOT: @llvm.cj.gc.statepoint{{.*}}@llvm.cj.gc.statepoint
; CHECK: @llvm.cj.gc.relocate
; CHECK: ret i8 addrspace(1)*
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj)
  ret i8 addrspace(1)* %obj
}

define void @leaf_throw(i8 addrspace(1)* %obj) gc "cangjie" {
; CHECK-LABEL: @leaf_throw(
; CHECK: call token ({{.*}}) @llvm.cj.gc.statepoint{{.*}}@CJ_MCC_ThrowException
; CHECK-NOT: gc-live
; CHECK-NOT: @llvm.cj.gc.statepoint{{.*}}@llvm.cj.gc.statepoint
; CHECK: ret void
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %obj) "gc-leaf-function"
  ret void
}

define void @already_wrapped(i8 addrspace(1)* %obj) gc "cangjie" {
; CHECK-LABEL: @already_wrapped(
; CHECK: call token ({{.*}}) @llvm.cj.gc.statepoint{{.*}}@CJ_MCC_ThrowException{{.*}} [ "gc-live"(i8 addrspace(1)* %obj)
; CHECK-NOT: @llvm.cj.gc.statepoint{{.*}}@llvm.cj.gc.statepoint
; CHECK: ret void
  call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, void (i8 addrspace(1)*)* @CJ_MCC_ThrowException, i32 1, i32 0, i8 addrspace(1)* %obj) [ "gc-live"(i8 addrspace(1)* %obj) ]
  ret void
}

define i8 addrspace(1)* @control_call(i8 addrspace(1)* %obj) gc "cangjie" {
; CHECK-LABEL: @control_call(
; CHECK: call token ({{.*}}) @llvm.cj.gc.statepoint{{.*}}@foo{{.*}} [ "gc-live"(i8 addrspace(1)* %obj)
; CHECK-NOT: @CJ_MCC_ThrowException
; CHECK: ret i8 addrspace(1)*
  call void @foo()
  ret i8 addrspace(1)* %obj
}

define void @control_invoke(i1 %c) gc "cangjie" personality i32* ()* @fake_personality_function {
; CHECK-LABEL: @control_invoke(
; CHECK: invoke token ({{.*}}) @llvm.cj.gc.statepoint{{.*}}@foo
; CHECK: landingpad
; CHECK: resume { i8*, i32 }
  br i1 %c, label %do_invoke, label %normal
do_invoke:
  invoke void @foo()
          to label %normal unwind label %unwind
unwind:
  %lpad = landingpad { i8*, i32 }
          cleanup
  resume { i8*, i32 } undef
normal:
  ret void
}

define void @throw_invoke() gc "cangjie" personality i32* ()* @fake_personality_function {
; CHECK-LABEL: @throw_invoke(
; CHECK: invoke token ({{.*}}) @llvm.cj.gc.statepoint{{.*}}@CJ_MCC_ThrowException
; CHECK-NOT: @llvm.cj.gc.statepoint{{.*}}@llvm.cj.gc.statepoint
; CHECK: landingpad
; CHECK: resume { i8*, i32 }
  invoke void @CJ_MCC_ThrowException(i8 addrspace(1)* null)
          to label %ok unwind label %unwind
ok:
  ret void
unwind:
  %lpad = landingpad { i8*, i32 }
          cleanup
  resume { i8*, i32 } undef
}

define void @throw_as_value() gc "cangjie" {
; CHECK-LABEL: @throw_as_value(
; CHECK: @llvm.cj.gc.statepoint{{.*}}@take{{.*}}@CJ_MCC_ThrowException
; CHECK-NOT: @llvm.cj.gc.statepoint{{.*}}@llvm.cj.gc.statepoint
; CHECK: ret void
  call void @take(void (i8 addrspace(1)*)* @CJ_MCC_ThrowException)
  ret void
}

@slot = global void (i8 addrspace(1)*)* @CJ_MCC_ThrowException
