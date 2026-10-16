; RUN: opt -opaque-pointers=0 -passes=verify -disable-output < %s
; RUN: opt -opaque-pointers=0 -passes=cj-rssce -S < %s | FileCheck %s
; RUN: opt -opaque-pointers=0 -passes='function(cj-rssce),always-inline,function(sroa,instcombine,simplifycfg)' -S < %s | FileCheck %s --check-prefix=RESULT
;
; Select destination propagation: only the parameter is readonly, while the
; function has no readonly attribute. Check both the rewritten argument and the
; value read by the real callee after RSSCE (without any earlier memcpyopt).

target datalayout = "e-p:64:64-i64:64-n8:16:32:64-S128"
%W = type { i64 }
declare void @llvm.memcpy.p0i8.p0i8.i64(i8* noalias nocapture writeonly, i8* noalias nocapture readonly, i64, i1 immarg)
define internal i64 @first(%W* nocapture readonly %p) #0 {
  %q = getelementptr inbounds %W, %W* %p, i64 0, i32 0
  %v = load i64, i64* %q, align 8
  ret i64 %v
}

; CHECK-LABEL: define i64 @read_before_store()
; CHECK: %r = call i64 @first(%W* %late)
; RESULT-LABEL: define i64 @read_before_store()
; RESULT-NEXT: ret i64 2
define i64 @read_before_store() {
  %src = alloca %W, align 8
  %early = alloca %W, align 8
  %late = alloca %W, align 8
  %s = getelementptr inbounds %W, %W* %src, i64 0, i32 0
  %e = getelementptr inbounds %W, %W* %early, i64 0, i32 0
  %l = getelementptr inbounds %W, %W* %late, i64 0, i32 0
  store i64 1, i64* %s, align 8
  %old = load i64, i64* %s, align 8
  store i64 2, i64* %s, align 8
  store i64 %old, i64* %e, align 8
  %new = load i64, i64* %s, align 8
  store i64 %new, i64* %l, align 8
  %r = call i64 @first(%W* %late)
  ret i64 %r
}

; CHECK-LABEL: define i64 @read_no_write()
; CHECK: %r = call i64 @first(%W* %early)
; RESULT-LABEL: define i64 @read_no_write()
; RESULT-NEXT: ret i64 1
define i64 @read_no_write() {
  %src = alloca %W, align 8
  %early = alloca %W, align 8
  %late = alloca %W, align 8
  %s = getelementptr inbounds %W, %W* %src, i64 0, i32 0
  %e = getelementptr inbounds %W, %W* %early, i64 0, i32 0
  %l = getelementptr inbounds %W, %W* %late, i64 0, i32 0
  store i64 1, i64* %s, align 8
  %old = load i64, i64* %s, align 8
  store i64 %old, i64* %e, align 8
  %new = load i64, i64* %s, align 8
  store i64 %new, i64* %l, align 8
  %r = call i64 @first(%W* %late)
  ret i64 %r
}

; CHECK-LABEL: define i64 @read_reverse_store_order()
; CHECK: %r = call i64 @first(%W* %late)
; RESULT-LABEL: define i64 @read_reverse_store_order()
; RESULT-NEXT: ret i64 1
define i64 @read_reverse_store_order() {
  %src = alloca %W, align 8
  %early = alloca %W, align 8
  %late = alloca %W, align 8
  %s = getelementptr inbounds %W, %W* %src, i64 0, i32 0
  %e = getelementptr inbounds %W, %W* %early, i64 0, i32 0
  %l = getelementptr inbounds %W, %W* %late, i64 0, i32 0
  store i64 1, i64* %s, align 8
  %old = load i64, i64* %s, align 8
  store i64 2, i64* %s, align 8
  %new = load i64, i64* %s, align 8
  store i64 %new, i64* %e, align 8
  store i64 %old, i64* %l, align 8
  %r = call i64 @first(%W* %late)
  ret i64 %r
}

; CHECK-LABEL: define i64 @same_snapshot_after_write()
; CHECK: %r = call i64 @first(%W* %early)
; RESULT-LABEL: define i64 @same_snapshot_after_write()
; RESULT-NEXT: ret i64 1
define i64 @same_snapshot_after_write() {
  %src = alloca %W, align 8
  %early = alloca %W, align 8
  %late = alloca %W, align 8
  %s = getelementptr inbounds %W, %W* %src, i64 0, i32 0
  %e = getelementptr inbounds %W, %W* %early, i64 0, i32 0
  %l = getelementptr inbounds %W, %W* %late, i64 0, i32 0
  store i64 1, i64* %s, align 8
  %old = load i64, i64* %s, align 8
  store i64 2, i64* %s, align 8
  store i64 %old, i64* %e, align 8
  store i64 %old, i64* %l, align 8
  %r = call i64 @first(%W* %late)
  ret i64 %r
}

attributes #0 = { alwaysinline argmemonly nounwind willreturn }
