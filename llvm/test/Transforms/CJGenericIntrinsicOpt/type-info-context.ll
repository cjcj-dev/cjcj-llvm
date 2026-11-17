; RUN: opt -passes=cj-type-info-context -verify-each -S < %s | FileCheck %s
;
; Forward an existing live generic context into an internal callee before
; runtime lowering. Unknown calls remain effectful; no runtime attributes change.
target datalayout = "e-m:e-p:64:64-i64:64-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
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

; Returning/observing a raw pointer does not prove a live metadata context.
; CHECK-LABEL: define i8* @pointer_only(
; CHECK: call void @worker(i8* %key)
; CHECK: ret i8* %ti
define i8* @pointer_only(i8* %key) gc "cangjie" {
entry:
  %a = alloca [1 x i8*], align 8
  %p = getelementptr [1 x i8*], [1 x i8*]* %a, i64 0, i64 0
  store i8* %key, i8** %p
  %ti = call i8* @llvm.cj.get.type.info(i8* @A, i32 1, i8** %p)
  call void @worker(i8* %key)
  ret i8* %ti
}

; Match recursively through immutable generic arguments and nested TI terms.
define internal void @nested_worker(i8** %outer) gc "cangjie" {
entry:
  %a = alloca [1 x i8*], align 8
  %b = alloca [1 x i8*], align 8
  %key = load i8*, i8** %outer, !invariant.load !0
  %p = getelementptr [1 x i8*], [1 x i8*]* %a, i64 0, i64 0
  %q = getelementptr [1 x i8*], [1 x i8*]* %b, i64 0, i64 0
  store i8* %key, i8** %p
  %inner = call i8* @llvm.cj.get.type.info(i8* @A, i32 1, i8** %p)
  store i8* %inner, i8** %q
  %outerti = call i8* @llvm.cj.get.type.info(i8* @B, i32 1, i8** %q)
  call void @observe(i8* %outerti)
  ret void
}
; CHECK-LABEL: define void @nested_context(
; CHECK: call i8* @llvm.cj.get.type.info
; CHECK: call i8* @llvm.cj.get.type.info
; CHECK: call void @opaque()
; CHECK-NOT: call i8* @llvm.cj.get.type.info
; CHECK-NOT: call void @nested_worker
; CHECK: call void @observe(i8* %outerti)
; CHECK: ret void
define void @nested_context(i8** %outer) gc "cangjie" {
entry:
  %a = alloca [1 x i8*], align 8
  %b = alloca [1 x i8*], align 8
  %key = load i8*, i8** %outer, !invariant.load !0
  %p = getelementptr [1 x i8*], [1 x i8*]* %a, i64 0, i64 0
  %q = getelementptr [1 x i8*], [1 x i8*]* %b, i64 0, i64 0
  store i8* %key, i8** %p
  %inner = call i8* @llvm.cj.get.type.info(i8* @A, i32 1, i8** %p)
  store i8* %inner, i8** %q
  %outerti = call i8* @llvm.cj.get.type.info(i8* @B, i32 1, i8** %q)
  call void @opaque()
  call void @nested_worker(i8** %outer)
  %x = call i64 @llvm.cj.get.field.offset(i8* %inner, i64 0, i32 0)
  %y = call i64 @llvm.cj.get.field.offset(i8* %outerti, i64 0, i32 0)
  ret void
}
; Missing invariant annotation prevents matching mutable context loads.
; CHECK-LABEL: define void @mutable_context(
; CHECK: call void @nested_worker(i8** %outer)
; CHECK: ret void
define void @mutable_context(i8** %outer) gc "cangjie" {
entry:
  %a = alloca [1 x i8*], align 8
  %b = alloca [1 x i8*], align 8
  %key = load i8*, i8** %outer
  %p = getelementptr [1 x i8*], [1 x i8*]* %a, i64 0, i64 0
  %q = getelementptr [1 x i8*], [1 x i8*]* %b, i64 0, i64 0
  store i8* %key, i8** %p
  %inner = call i8* @llvm.cj.get.type.info(i8* @A, i32 1, i8** %p)
  store i8* %inner, i8** %q
  %outerti = call i8* @llvm.cj.get.type.info(i8* @B, i32 1, i8** %q)
  call void @opaque()
  call void @nested_worker(i8** %outer)
  %x = call i64 @llvm.cj.get.field.offset(i8* %inner, i64 0, i32 0)
  %y = call i64 @llvm.cj.get.field.offset(i8* %outerti, i64 0, i32 0)
  ret void
}
!0 = !{}

; A later context has a layout use, but cannot initialize an earlier callee.
; CHECK-LABEL: define void @late_context(
; CHECK: call void @worker(i8* %key)
; CHECK: call i8* @llvm.cj.get.type.info
; CHECK: ret void
define void @late_context(i8* %key) gc "cangjie" {
entry:
  %a = alloca [1 x i8*], align 8
  %p = getelementptr [1 x i8*], [1 x i8*]* %a, i64 0, i64 0
  store i8* %key, i8** %p
  call void @worker(i8* %key)
  %ti = call i8* @llvm.cj.get.type.info(i8* @A, i32 1, i8** %p)
  %offset = call i64 @llvm.cj.get.field.offset(i8* %ti, i64 0, i32 0)
  ret void
}

; Standard call-site noinline remains a veto despite an exact live context.
; CHECK-LABEL: define void @noinline_site(
; CHECK: call void @worker(i8* %key)
; CHECK: ret void
define void @noinline_site(i8* %key) gc "cangjie" {
entry:
  %a = alloca [1 x i8*], align 8
  %p = getelementptr [1 x i8*], [1 x i8*]* %a, i64 0, i64 0
  store i8* %key, i8** %p
  %ti = call i8* @llvm.cj.get.type.info(i8* @A, i32 1, i8** %p)
  call void @worker(i8* %key) noinline
  %offset = call i64 @llvm.cj.get.field.offset(i8* %ti, i64 0, i32 0)
  ret void
}

define internal void @too_costly(i8* %key) gc "cangjie" {
entry:
  %a = alloca [1 x i8*], align 8
  %p = getelementptr [1 x i8*], [1 x i8*]* %a, i64 0, i64 0
  store i8* %key, i8** %p
  %ti = call i8* @llvm.cj.get.type.info(i8* @A, i32 1, i8** %p)
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @opaque()
  call void @observe(i8* %ti)
  ret void
}
; This body is below the structural 512-instruction cap but exceeds the
; ordinary inliner cost. Context equality must not override that decision.
; A formal TI argument maps only by actual SSA identity. Independently
; acquired caller queries do not provide an identity/lifetime fact, even if
; their template and arguments appear equal.
; CHECK-LABEL: define void @independent_actual_context(
; CHECK: call i8* @llvm.cj.get.type.info
; CHECK: call i8* @llvm.cj.get.type.info
; CHECK: call i8* @llvm.cj.get.type.info
; CHECK: call void @worker(i8* %second)
; CHECK: ret void
define void @independent_actual_context(i8* %key) gc "cangjie" {
entry:
  %a = alloca [1 x i8*], align 8
  %ap = getelementptr [1 x i8*], [1 x i8*]* %a, i64 0, i64 0
  store i8* %key, i8** %ap
  %first = call i8* @llvm.cj.get.type.info(i8* @B, i32 1, i8** %ap)
  %b = alloca [1 x i8*], align 8
  %bp = getelementptr [1 x i8*], [1 x i8*]* %b, i64 0, i64 0
  store i8* %first, i8** %bp
  %context = call i8* @llvm.cj.get.type.info(i8* @A, i32 1, i8** %bp)
  call void @opaque()
  %c = alloca [1 x i8*], align 8
  %cp = getelementptr [1 x i8*], [1 x i8*]* %c, i64 0, i64 0
  store i8* %key, i8** %cp
  %second = call i8* @llvm.cj.get.type.info(i8* @B, i32 1, i8** %cp)
  call void @worker(i8* %second)
  %offset = call i64 @llvm.cj.get.field.offset(i8* %context, i64 0, i32 0)
  ret void
}

; Keep a second real caller so ordinary inlining cannot claim the
; last-call-to-static code-size benefit. This caller has no live TI context.
define void @cost_second_use(i8* %key) gc "cangjie" {
  call void @too_costly(i8* %key)
  ret void
}

; CHECK-LABEL: define void @cost_veto(
; CHECK: call void @too_costly(i8* %key)
; CHECK: ret void
define void @cost_veto(i8* %key) gc "cangjie" {
entry:
  %a = alloca [1 x i8*], align 8
  %p = getelementptr [1 x i8*], [1 x i8*]* %a, i64 0, i64 0
  store i8* %key, i8** %p
  %ti = call i8* @llvm.cj.get.type.info(i8* @A, i32 1, i8** %p)
  call void @too_costly(i8* %key)
  %offset = call i64 @llvm.cj.get.field.offset(i8* %ti, i64 0, i32 0)
  ret void
}
