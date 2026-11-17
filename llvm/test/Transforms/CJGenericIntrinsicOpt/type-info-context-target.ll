; RUN: opt -passes=cj-type-info-context -verify-each -S < %s | FileCheck %s --check-prefix=KEEP
; RUN: opt -mtriple=x86_64-unknown-linux-gnu -passes=cj-type-info-context -verify-each -S < %s | FileCheck %s --check-prefix=REUSE
; RUN: opt -mtriple=x86_64-pc-linux-gnu -passes=cj-type-info-context -verify-each -S < %s | FileCheck %s --check-prefix=REUSE
; RUN: opt -mtriple=x86_64-unknown-linux-musl -passes=cj-type-info-context -verify-each -S < %s | FileCheck %s --check-prefix=KEEP
; RUN: opt -mtriple=x86_64-unknown-linux-android -passes=cj-type-info-context -verify-each -S < %s | FileCheck %s --check-prefix=KEEP
; RUN: opt -mtriple=x86_64-unknown-linux-ohos -passes=cj-type-info-context -verify-each -S < %s | FileCheck %s --check-prefix=KEEP
; RUN: opt -mtriple=x86_64-unknown-linux -passes=cj-type-info-context -verify-each -S < %s | FileCheck %s --check-prefix=KEEP
; RUN: opt -mtriple=x86_64-pc-windows-gnu -passes=cj-type-info-context -verify-each -S < %s | FileCheck %s --check-prefix=KEEP
; RUN: opt -mtriple=x86_64-pc-windows-msvc -passes=cj-type-info-context -verify-each -S < %s | FileCheck %s --check-prefix=KEEP
; RUN: opt -mtriple=x86_64-apple-macosx -passes=cj-type-info-context -verify-each -S < %s | FileCheck %s --check-prefix=KEEP
; RUN: opt -mtriple=x86_64-unknown-freebsd -passes=cj-type-info-context -verify-each -S < %s | FileCheck %s --check-prefix=KEEP
; RUN: opt -mtriple=aarch64-unknown-linux-gnu -passes=cj-type-info-context -verify-each -S < %s | FileCheck %s --check-prefix=KEEP
; RUN: opt -mtriple=x86_64-unknown-linux-gnux32 -passes=cj-type-info-context -verify-each -S < %s | FileCheck %s --check-prefix=KEEP
; RUN: opt -mtriple=unknown-unknown-linux-gnu -passes=cj-type-info-context -verify-each -S < %s | FileCheck %s --check-prefix=KEEP
;
; The pass consumes the module target's runtime image-retention policy. The
; compiler host's libc, Linux OS alone, or a GNU environment on another OS is
; insufficient. Missing targets and unqualified architectures/ABIs keep the
; original query/call even when the same live context would otherwise match.
target datalayout = "e-m:e-p:64:64-i64:64-n8:16:32:64-S128"

@A = external global i8
declare i8* @llvm.cj.get.type.info(i8*, i32, i8**)
declare i64 @llvm.cj.get.field.offset(i8*, i64, i32)
declare void @observe(i8*)
declare void @opaque()

define internal void @worker(i8* %key) gc "cangjie" {
  %a = alloca [1 x i8*], align 8
  %p = getelementptr [1 x i8*], [1 x i8*]* %a, i64 0, i64 0
  store i8* %key, i8** %p
  %ti = call i8* @llvm.cj.get.type.info(i8* @A, i32 1, i8** %p)
  call void @observe(i8* %ti)
  ret void
}

; KEEP-LABEL: define void @live_context(
; KEEP: %ti = call i8* @llvm.cj.get.type.info
; KEEP-NEXT: call void @opaque()
; KEEP-NEXT: call void @worker(i8* %key)
; KEEP-NEXT: %offset = call i64 @llvm.cj.get.field.offset(i8* %ti,
; KEEP-NEXT: ret void
;
; REUSE-LABEL: define void @live_context(
; REUSE: %ti = call i8* @llvm.cj.get.type.info
; REUSE: call void @opaque()
; REUSE-NOT: call i8* @llvm.cj.get.type.info
; REUSE-NOT: call void @worker
; REUSE: call void @observe(i8* %ti)
; REUSE: %offset = call i64 @llvm.cj.get.field.offset(i8* %ti,
; REUSE: ret void
define void @live_context(i8* %key) gc "cangjie" {
  %a = alloca [1 x i8*], align 8
  %p = getelementptr [1 x i8*], [1 x i8*]* %a, i64 0, i64 0
  store i8* %key, i8** %p
  %ti = call i8* @llvm.cj.get.type.info(i8* @A, i32 1, i8** %p)
  call void @opaque()
  call void @worker(i8* %key)
  %offset = call i64 @llvm.cj.get.field.offset(i8* %ti, i64 0, i32 0)
  ret void
}
