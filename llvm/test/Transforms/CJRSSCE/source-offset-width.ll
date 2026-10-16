; RUN: opt -opaque-pointers=0 -passes=cj-rssce -S < %s | FileCheck %s --check-prefixes=CHECK,TYPED
; RUN: opt -opaque-pointers=1 -passes=cj-rssce -S < %s | FileCheck %s --check-prefixes=CHECK,OPAQUE
;
; This is an IR transformation test: opt does not execute the large alloca.
; Preserve the actual source offset when it exceeds a 32-bit GEP index.

target datalayout = "e-p:64:64-i64:64-n8:16:32:64-S128"
%S = type { i64, i64 }

declare i64 @sum(%S*) readonly
declare void @llvm.memcpy.p0i8.p0i8.i64(i8* noalias nocapture writeonly, i8* noalias nocapture readonly, i64, i1 immarg)

; CHECK-LABEL: define i64 @wide_source_offset()
; TYPED: [[BASE:%.*]] = bitcast %S* %src to i8*
; TYPED-NEXT: [[RANGE:%.*]] = getelementptr inbounds i8, i8* [[BASE]], i64 4294967296
; TYPED: [[ARG:%.*]] = bitcast i8* [[RANGE]] to %S*
; TYPED-NEXT: %r = call i64 @sum(%S* [[ARG]])
; OPAQUE: [[RANGE:%.*]] = getelementptr inbounds i8, ptr %src, i64 4294967296
; OPAQUE: %r = call i64 @sum(ptr [[RANGE]])
define i64 @wide_source_offset() {
  %src = alloca %S, i64 268435457, align 8
  %dst = alloca %S, align 8
  %a = getelementptr inbounds %S, %S* %src, i64 268435456, i32 0
  %b = getelementptr inbounds %S, %S* %src, i64 268435456, i32 1
  store i64 1, i64* %a, align 8
  store i64 2, i64* %b, align 8
  %last = getelementptr inbounds %S, %S* %src, i64 268435456
  %s = bitcast %S* %last to i8*
  %d = bitcast %S* %dst to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d, i8* %s, i64 16, i1 false)
  %r = call i64 @sum(%S* %dst)
  ret i64 %r
}
