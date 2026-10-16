; RUN: opt -opaque-pointers=0 -passes=cj-rssce -S < %s | FileCheck %s
; RUN: opt -opaque-pointers=0 -passes='function(cj-rssce),always-inline,function(sroa,instcombine,simplifycfg)' -S < %s | FileCheck %s --check-prefix=RESULT
;
; Updating an existing copy destination after a source write erases its old
; state. The fresh definition must be registered in the rebound destination,
; and then consumed by a later equivalent copy. A store-based control uses
; different read snapshots with no intervening write.
target datalayout = "e-p:64:64-i64:64-n8:16:32:64-S128"
%W = type { i64 }
declare void @llvm.memcpy.p0i8.p0i8.i64(i8* noalias nocapture writeonly, i8* noalias nocapture readonly, i64, i1 immarg)
define internal i64 @read(%W* nocapture readonly %p) #0 {
  %q = getelementptr inbounds %W, %W* %p, i64 0, i32 0
  %v = load i64, i64* %q, align 8
  ret i64 %v
}

; CHECK-LABEL: define i64 @source_invalidation_rebind()
; CHECK: %r = call i64 @read(%W* %early)
; RESULT-LABEL: define i64 @source_invalidation_rebind()
; RESULT-NEXT: ret i64 9
define i64 @source_invalidation_rebind() {
  %src = alloca %W, align 8
  %early = alloca %W, align 8
  %late = alloca %W, align 8
  %field = getelementptr inbounds %W, %W* %src, i64 0, i32 0
  store i64 1, i64* %field, align 8
  %s = bitcast %W* %src to i8*
  %e = bitcast %W* %early to i8*
  %l = bitcast %W* %late to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %e, i8* %s, i64 8, i1 false)
  store i64 9, i64* %field, align 8
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %e, i8* %s, i64 8, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %l, i8* %s, i64 8, i1 false)
  %r = call i64 @read(%W* %late)
  ret i64 %r
}

; CHECK-LABEL: define i64 @no_source_invalidation()
; CHECK: %r = call i64 @read(%W* %early)
; RESULT-LABEL: define i64 @no_source_invalidation()
; RESULT-NEXT: ret i64 9
define i64 @no_source_invalidation() {
  %src = alloca %W, align 8
  %early = alloca %W, align 8
  %late = alloca %W, align 8
  %field = getelementptr inbounds %W, %W* %src, i64 0, i32 0
  store i64 9, i64* %field, align 8
  %s = bitcast %W* %src to i8*
  %e = bitcast %W* %early to i8*
  %l = bitcast %W* %late to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %e, i8* %s, i64 8, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %e, i8* %s, i64 8, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %l, i8* %s, i64 8, i1 false)
  %r = call i64 @read(%W* %late)
  ret i64 %r
}

; CHECK-LABEL: define i64 @stored_snapshot_control()
; CHECK: %r = call i64 @read(%W* %early)
; RESULT-LABEL: define i64 @stored_snapshot_control()
; RESULT-NEXT: ret i64 9
define i64 @stored_snapshot_control() {
  %src = alloca %W, align 8
  %early = alloca %W, align 8
  %late = alloca %W, align 8
  %s = getelementptr inbounds %W, %W* %src, i64 0, i32 0
  %e = getelementptr inbounds %W, %W* %early, i64 0, i32 0
  %l = getelementptr inbounds %W, %W* %late, i64 0, i32 0
  store i64 9, i64* %s, align 8
  %old = load i64, i64* %s, align 8
  store i64 %old, i64* %e, align 8
  %new = load i64, i64* %s, align 8
  store i64 %new, i64* %l, align 8
  %r = call i64 @read(%W* %late)
  ret i64 %r
}
attributes #0 = { alwaysinline argmemonly nounwind willreturn }
