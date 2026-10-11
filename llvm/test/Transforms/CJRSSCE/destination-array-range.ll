; RUN: opt -opaque-pointers=0 -passes=cj-rssce -S < %s | FileCheck %s
; RUN: opt -opaque-pointers=0 -passes='function(cj-rssce),always-inline,function(sroa,instcombine,simplifycfg)' -S < %s | FileCheck %s --check-prefix=RESULT
;
; Destination propagation shares the whole-object source/destination query.
; @sum has a readonly parameter but no readonly function attribute, selecting
; destination propagation rather than source propagation.
; Opaque destination propagation still has a separate pointee-type dependency
; in tryToReplaceCallArgs. Do not use that earlier failure as range evidence.

target datalayout = "e-p:64:64-i64:64-n8:16:32:64-S128"

%S = type { i64, i64 }

declare void @llvm.memcpy.p0i8.p0i8.i64(i8* noalias nocapture writeonly, i8* noalias nocapture readonly, i64, i1 immarg)

define internal i64 @sum(%S* nocapture readonly %p) #0 {
  %a = getelementptr inbounds %S, %S* %p, i64 0, i32 0
  %b = getelementptr inbounds %S, %S* %p, i64 0, i32 1
  %x = load i64, i64* %a, align 8
  %y = load i64, i64* %b, align 8
  %r = add i64 %x, %y
  ret i64 %r
}

; A source write between the two copies invalidates their equivalence.
; CHECK-LABEL: define i64 @source_changed_between_copies()
; CHECK: %r = call i64 @sum(%S* %late.second)
; RESULT-LABEL: define i64 @source_changed_between_copies()
; RESULT-NEXT: ret i64 11
define i64 @source_changed_between_copies() {
  %src = alloca %S, i64 2, align 8
  %early = alloca %S, i64 2, align 8
  %late = alloca %S, i64 2, align 8
  %first.a = getelementptr inbounds %S, %S* %src, i64 0, i32 0
  %first.b = getelementptr inbounds %S, %S* %src, i64 0, i32 1
  store i64 0, i64* %first.a, align 8
  store i64 0, i64* %first.b, align 8
  %a = getelementptr inbounds %S, %S* %src, i64 1, i32 0
  %b = getelementptr inbounds %S, %S* %src, i64 1, i32 1
  store i64 1, i64* %a, align 8
  store i64 2, i64* %b, align 8
  %src.second = getelementptr inbounds %S, %S* %src, i64 1
  %early.second = getelementptr inbounds %S, %S* %early, i64 1
  %late.second = getelementptr inbounds %S, %S* %late, i64 1
  %s = bitcast %S* %src to i8*
  %e = bitcast %S* %early to i8*
  %l = bitcast %S* %late to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %e, i8* %s, i64 32, i1 false)
  store i64 9, i64* %a, align 8
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %l, i8* %s, i64 32, i1 false)
  %r = call i64 @sum(%S* %late.second)
  ret i64 %r
}

; The earlier candidate destination changed after its copy.
; CHECK-LABEL: define i64 @candidate_destination_changed()
; CHECK: %r = call i64 @sum(%S* %late.second)
; RESULT-LABEL: define i64 @candidate_destination_changed()
; RESULT-NEXT: ret i64 3
define i64 @candidate_destination_changed() {
  %src = alloca %S, i64 2, align 8
  %early = alloca %S, i64 2, align 8
  %late = alloca %S, i64 2, align 8
  %first.a = getelementptr inbounds %S, %S* %src, i64 0, i32 0
  %first.b = getelementptr inbounds %S, %S* %src, i64 0, i32 1
  store i64 0, i64* %first.a, align 8
  store i64 0, i64* %first.b, align 8
  %a = getelementptr inbounds %S, %S* %src, i64 1, i32 0
  %b = getelementptr inbounds %S, %S* %src, i64 1, i32 1
  store i64 1, i64* %a, align 8
  store i64 2, i64* %b, align 8
  %src.second = getelementptr inbounds %S, %S* %src, i64 1
  %early.second = getelementptr inbounds %S, %S* %early, i64 1
  %late.second = getelementptr inbounds %S, %S* %late, i64 1
  %s = bitcast %S* %src to i8*
  %e = bitcast %S* %early to i8*
  %l = bitcast %S* %late to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %e, i8* %s, i64 32, i1 false)
  %early.a = getelementptr inbounds %S, %S* %early, i64 1, i32 0
  store i64 9, i64* %early.a, align 8
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %l, i8* %s, i64 32, i1 false)
  %r = call i64 @sum(%S* %late.second)
  ret i64 %r
}

; The current destination changed after its own copy.
; CHECK-LABEL: define i64 @current_destination_changed()
; CHECK: %r = call i64 @sum(%S* %late.second)
; RESULT-LABEL: define i64 @current_destination_changed()
; RESULT-NEXT: ret i64 11
define i64 @current_destination_changed() {
  %src = alloca %S, i64 2, align 8
  %early = alloca %S, i64 2, align 8
  %late = alloca %S, i64 2, align 8
  %first.a = getelementptr inbounds %S, %S* %src, i64 0, i32 0
  %first.b = getelementptr inbounds %S, %S* %src, i64 0, i32 1
  store i64 0, i64* %first.a, align 8
  store i64 0, i64* %first.b, align 8
  %a = getelementptr inbounds %S, %S* %src, i64 1, i32 0
  %b = getelementptr inbounds %S, %S* %src, i64 1, i32 1
  store i64 1, i64* %a, align 8
  store i64 2, i64* %b, align 8
  %src.second = getelementptr inbounds %S, %S* %src, i64 1
  %early.second = getelementptr inbounds %S, %S* %early, i64 1
  %late.second = getelementptr inbounds %S, %S* %late, i64 1
  %s = bitcast %S* %src to i8*
  %e = bitcast %S* %early to i8*
  %l = bitcast %S* %late to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %e, i8* %s, i64 32, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %l, i8* %s, i64 32, i1 false)
  %late.a = getelementptr inbounds %S, %S* %late, i64 1, i32 0
  store i64 9, i64* %late.a, align 8
  %r = call i64 @sum(%S* %late.second)
  ret i64 %r
}

; Positive control: two unchanged copies are still equivalent.
; CHECK-LABEL: define i64 @unchanged_array_copies()
; CHECK: [[BASE:%[0-9]+]] = bitcast %S* %early to i8*
; CHECK-NEXT: [[RANGE:%.*]] = getelementptr inbounds i8, i8* [[BASE]], i64 16
; CHECK-NEXT: [[ARG:%.*]] = bitcast i8* [[RANGE]] to %S*
; CHECK-NEXT: %r = call i64 @sum(%S* [[ARG]])
; RESULT-LABEL: define i64 @unchanged_array_copies()
; RESULT-NEXT: ret i64 3
define i64 @unchanged_array_copies() {
  %src = alloca %S, i64 2, align 8
  %early = alloca %S, i64 2, align 8
  %late = alloca %S, i64 2, align 8
  %first.a = getelementptr inbounds %S, %S* %src, i64 0, i32 0
  %first.b = getelementptr inbounds %S, %S* %src, i64 0, i32 1
  store i64 0, i64* %first.a, align 8
  store i64 0, i64* %first.b, align 8
  %a = getelementptr inbounds %S, %S* %src, i64 1, i32 0
  %b = getelementptr inbounds %S, %S* %src, i64 1, i32 1
  store i64 1, i64* %a, align 8
  store i64 2, i64* %b, align 8
  %src.second = getelementptr inbounds %S, %S* %src, i64 1
  %early.second = getelementptr inbounds %S, %S* %early, i64 1
  %late.second = getelementptr inbounds %S, %S* %late, i64 1
  %s = bitcast %S* %src to i8*
  %e = bitcast %S* %early to i8*
  %l = bitcast %S* %late to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %e, i8* %s, i64 32, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %l, i8* %s, i64 32, i1 false)
  %r = call i64 @sum(%S* %late.second)
  ret i64 %r
}

attributes #0 = { alwaysinline argmemonly nounwind willreturn }
