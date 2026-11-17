; RUN: opt -passes=cj-type-info-context -verify-each -S < %s | FileCheck %s
;
; Forward an existing live generic context into an internal callee before
; runtime lowering. Unknown calls remain effectful; no runtime attributes change.
target datalayout = "e-m:e-p:64:64-i64:64-n8:16:32:64-S128"
@A = external global i8
@B = external global i8
declare i8* @llvm.cj.get.type.info(i8*, i32, i8**)
declare i64 @llvm.cj.get.field.offset(i8*, i64, i32)
declare void @observe(i8*)
declare void @opaque()
declare void @escape(i8**)
declare void @unknown(i8*)

define internal void @worker(i8* %key) gc "cangjie" {
entry:
  %a = alloca [1 x i8*], align 8
  %p = getelementptr [1 x i8*], [1 x i8*]* %a, i64 0, i64 0
  store i8* %key, i8** %p
  %ti = call i8* @llvm.cj.get.type.info(i8* @A, i32 1, i8** %p)
  call void @observe(i8* %ti)
  ret void
}

define internal void @after_effect(i8* %key) gc "cangjie" {
entry:
  %a = alloca [1 x i8*], align 8
  %p = getelementptr [1 x i8*], [1 x i8*]* %a, i64 0, i64 0
  store i8* %key, i8** %p
  call void @opaque()
  %ti = call i8* @llvm.cj.get.type.info(i8* @A, i32 1, i8** %p)
  call void @observe(i8* %ti)
  ret void
}

; CHECK-LABEL: define void @live_context(
; CHECK: call i8* @llvm.cj.get.type.info
; CHECK: call void @opaque()
; CHECK-NOT: call i8* @llvm.cj.get.type.info
; CHECK-NOT: call void @worker
; CHECK: call void @observe(i8* %ti)
; CHECK: ret void
define void @live_context(i8* %key, i8* %other) gc "cangjie" {
entry:
  %a = alloca [1 x i8*], align 8
  %p = getelementptr [1 x i8*], [1 x i8*]* %a, i64 0, i64 0
  store i8* %key, i8** %p
  %ti = call i8* @llvm.cj.get.type.info(i8* @A, i32 1, i8** %p)
  
  call void @opaque()
  call void @worker(i8* %key)
  %offset = call i64 @llvm.cj.get.field.offset(i8* %ti, i64 0, i32 0)
  ret void
}

; CHECK-LABEL: define void @different_template(
; CHECK: call i8* @llvm.cj.get.type.info
; CHECK: call void @worker(i8* %key)
; CHECK: ret void
define void @different_template(i8* %key, i8* %other) gc "cangjie" {
entry:
  %a = alloca [1 x i8*], align 8
  %p = getelementptr [1 x i8*], [1 x i8*]* %a, i64 0, i64 0
  store i8* %key, i8** %p
  %ti = call i8* @llvm.cj.get.type.info(i8* @B, i32 1, i8** %p)
  
  call void @opaque()
  call void @worker(i8* %key)
  %offset = call i64 @llvm.cj.get.field.offset(i8* %ti, i64 0, i32 0)
  ret void
}

; CHECK-LABEL: define void @different_arg(
; CHECK: call i8* @llvm.cj.get.type.info
; CHECK: call void @worker(i8* %other)
; CHECK: ret void
define void @different_arg(i8* %key, i8* %other) gc "cangjie" {
entry:
  %a = alloca [1 x i8*], align 8
  %p = getelementptr [1 x i8*], [1 x i8*]* %a, i64 0, i64 0
  store i8* %key, i8** %p
  %ti = call i8* @llvm.cj.get.type.info(i8* @A, i32 1, i8** %p)
  
  call void @opaque()
  call void @worker(i8* %other)
  %offset = call i64 @llvm.cj.get.field.offset(i8* %ti, i64 0, i32 0)
  ret void
}

; CHECK-LABEL: define void @write_args(
; CHECK: call i8* @llvm.cj.get.type.info
; CHECK: call void @worker(i8* %key)
; CHECK: ret void
define void @write_args(i8* %key, i8* %other) gc "cangjie" {
entry:
  %a = alloca [1 x i8*], align 8
  %p = getelementptr [1 x i8*], [1 x i8*]* %a, i64 0, i64 0
  store i8* %key, i8** %p
  %ti = call i8* @llvm.cj.get.type.info(i8* @A, i32 1, i8** %p)
  store i8* %other, i8** %p
  call void @opaque()
  call void @worker(i8* %key)
  %offset = call i64 @llvm.cj.get.field.offset(i8* %ti, i64 0, i32 0)
  ret void
}

; CHECK-LABEL: define void @escape_args(
; CHECK: call i8* @llvm.cj.get.type.info
; CHECK: call void @worker(i8* %key)
; CHECK: ret void
define void @escape_args(i8* %key, i8* %other) gc "cangjie" {
entry:
  %a = alloca [1 x i8*], align 8
  %p = getelementptr [1 x i8*], [1 x i8*]* %a, i64 0, i64 0
  store i8* %key, i8** %p
  %ti = call i8* @llvm.cj.get.type.info(i8* @A, i32 1, i8** %p)
  call void @escape(i8** %p)
  call void @opaque()
  call void @worker(i8* %key)
  %offset = call i64 @llvm.cj.get.field.offset(i8* %ti, i64 0, i32 0)
  ret void
}

; CHECK-LABEL: define void @no_live_context(
; CHECK: call i8* @llvm.cj.get.type.info
; CHECK: call void @worker(i8* %key)
; CHECK: ret void
define void @no_live_context(i8* %key, i8* %other) gc "cangjie" {
entry:
  %a = alloca [1 x i8*], align 8
  %p = getelementptr [1 x i8*], [1 x i8*]* %a, i64 0, i64 0
  store i8* %key, i8** %p
  %ti = call i8* @llvm.cj.get.type.info(i8* @A, i32 1, i8** %p)
  
  call void @opaque()
  call void @worker(i8* %key)
  
  ret void
}

; CHECK-LABEL: define void @unknown_call(
; CHECK: call i8* @llvm.cj.get.type.info
; CHECK: call void @unknown(i8* %key)
; CHECK: ret void
define void @unknown_call(i8* %key, i8* %other) gc "cangjie" {
entry:
  %a = alloca [1 x i8*], align 8
  %p = getelementptr [1 x i8*], [1 x i8*]* %a, i64 0, i64 0
  store i8* %key, i8** %p
  %ti = call i8* @llvm.cj.get.type.info(i8* @A, i32 1, i8** %p)
  
  call void @opaque()
  call void @unknown(i8* %key)
  %offset = call i64 @llvm.cj.get.field.offset(i8* %ti, i64 0, i32 0)
  ret void
}

; CHECK-LABEL: define void @initializer_before_query(
; CHECK: call i8* @llvm.cj.get.type.info
; CHECK: call void @after_effect(i8* %key)
; CHECK: ret void
define void @initializer_before_query(i8* %key, i8* %other) gc "cangjie" {
entry:
  %a = alloca [1 x i8*], align 8
  %p = getelementptr [1 x i8*], [1 x i8*]* %a, i64 0, i64 0
  store i8* %key, i8** %p
  %ti = call i8* @llvm.cj.get.type.info(i8* @A, i32 1, i8** %p)
  
  call void @opaque()
  call void @after_effect(i8* %key)
  %offset = call i64 @llvm.cj.get.field.offset(i8* %ti, i64 0, i32 0)
  ret void
}

; A query confined to one arm cannot be forwarded into the join.
; CHECK-LABEL: define void @non_dominating(
; CHECK: call void @worker(i8* %key)
; CHECK: ret void
define void @non_dominating(i8* %key, i1 %cond) gc "cangjie" {
entry:
  %a = alloca [1 x i8*], align 8
  %p = getelementptr [1 x i8*], [1 x i8*]* %a, i64 0, i64 0
  store i8* %key, i8** %p
  br i1 %cond, label %left, label %join
left:
  %ti = call i8* @llvm.cj.get.type.info(i8* @A, i32 1, i8** %p)
  call void @observe(i8* %ti)
  br label %join
join:
  call void @worker(i8* %key)
  ret void
}

; The LRU shape: the callee is conditional but its context consumer is at
; the common normal-return join. The earlier query still dominates the call.
; CHECK-LABEL: define void @conditional_live_context(
; CHECK: call i8* @llvm.cj.get.type.info
; CHECK-NOT: call void @worker
; CHECK: call i64 @llvm.cj.get.field.offset(i8* %ti
; CHECK: ret void
define void @conditional_live_context(i8* %key, i1 %turn) gc "cangjie" {
entry:
  %a = alloca [1 x i8*], align 8
  %p = getelementptr [1 x i8*], [1 x i8*]* %a, i64 0, i64 0
  store i8* %key, i8** %p
  %ti = call i8* @llvm.cj.get.type.info(i8* @A, i32 1, i8** %p)
  br i1 %turn, label %yes, label %join
yes:
  call void @worker(i8* %key)
  br label %join
join:
  %offset = call i64 @llvm.cj.get.field.offset(i8* %ti, i64 0, i32 0)
  ret void
}
