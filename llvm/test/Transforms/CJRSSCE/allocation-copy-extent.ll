; RUN: opt -opaque-pointers=0 -passes=cj-rssce -S < %s | FileCheck %s
; RUN: opt -opaque-pointers=0 -passes='function(cj-rssce),always-inline,function(sroa,instcombine,simplifycfg)' -S < %s | FileCheck %s --check-prefix=RESULT
;
; A readonly call can legally read every element of an alloca array. Covering
; one struct element does not establish equivalence of the whole allocation.
; The destination propagation entry retains its separate opaque prerequisite.

target datalayout = "e-p:64:64-i64:64-n8:16:32:64-S128"
%S = type { i64, i64 }

declare void @llvm.memcpy.p0i8.p0i8.i64(i8* noalias nocapture writeonly, i8* noalias nocapture readonly, i64, i1 immarg)

define internal i64 @sum_all(%S* %p) #0 {
  %a = getelementptr inbounds %S, %S* %p, i64 0, i32 0
  %b = getelementptr inbounds %S, %S* %p, i64 0, i32 1
  %c = getelementptr inbounds %S, %S* %p, i64 1, i32 0
  %d = getelementptr inbounds %S, %S* %p, i64 1, i32 1
  %x = load i64, i64* %a, align 8
  %y = load i64, i64* %b, align 8
  %z = load i64, i64* %c, align 8
  %w = load i64, i64* %d, align 8
  %xy = add i64 %x, %y
  %zw = add i64 %z, %w
  %r = add i64 %xy, %zw
  ret i64 %r
}

define internal i64 @sum_all_dest(%S* nocapture readonly %p) #1 {
  %r = call i64 @sum_all(%S* %p)
  ret i64 %r
}

; Source propagation: copying 16 of 32 destination bytes is insufficient.
; CHECK-LABEL: define i64 @partial_array_source_propagation()
; CHECK: %r = call i64 @sum_all(%S* %dst)
; RESULT-LABEL: define i64 @partial_array_source_propagation()
; RESULT-NEXT: ret i64 15
define i64 @partial_array_source_propagation() {
  %src = alloca %S, i64 2, align 8
  %dst = alloca %S, i64 2, align 8
  %a = getelementptr inbounds %S, %S* %src, i64 0, i32 0
  %b = getelementptr inbounds %S, %S* %src, i64 0, i32 1
  %c = getelementptr inbounds %S, %S* %src, i64 1, i32 0
  %e = getelementptr inbounds %S, %S* %src, i64 1, i32 1
  store i64 1, i64* %a, align 8
  store i64 2, i64* %b, align 8
  store i64 40, i64* %c, align 8
  store i64 80, i64* %e, align 8
  %dc = getelementptr inbounds %S, %S* %dst, i64 1, i32 0
  %de = getelementptr inbounds %S, %S* %dst, i64 1, i32 1
  store i64 4, i64* %dc, align 8
  store i64 8, i64* %de, align 8
  %s = bitcast %S* %src to i8*
  %d = bitcast %S* %dst to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d, i8* %s, i64 16, i1 false)
  %r = call i64 @sum_all(%S* %dst)
  ret i64 %r
}

; Positive control: a complete 32-byte array copy can still be propagated.
; CHECK-LABEL: define i64 @full_array_source_propagation()
; CHECK: [[BASE:%[0-9]+]] = bitcast %S* %src to i8*
; CHECK-NEXT: [[RANGE:%.*]] = getelementptr inbounds i8, i8* [[BASE]], i64 0
; CHECK: [[ARG:%.*]] = bitcast i8* [[RANGE]] to %S*
; CHECK-NEXT: %r = call i64 @sum_all(%S* [[ARG]])
; RESULT-LABEL: define i64 @full_array_source_propagation()
; RESULT-NEXT: ret i64 15
define i64 @full_array_source_propagation() {
  %src = alloca %S, i64 2, align 8
  %dst = alloca %S, i64 2, align 8
  %a = getelementptr inbounds %S, %S* %src, i64 0, i32 0
  %b = getelementptr inbounds %S, %S* %src, i64 0, i32 1
  %c = getelementptr inbounds %S, %S* %src, i64 1, i32 0
  %e = getelementptr inbounds %S, %S* %src, i64 1, i32 1
  store i64 1, i64* %a, align 8
  store i64 2, i64* %b, align 8
  store i64 4, i64* %c, align 8
  store i64 8, i64* %e, align 8
  %s = bitcast %S* %src to i8*
  %d = bitcast %S* %dst to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d, i8* %s, i64 32, i1 false)
  %r = call i64 @sum_all(%S* %dst)
  ret i64 %r
}

; The 32-byte transfer must protect writes to its second source element too.
; CHECK-LABEL: define i64 @full_array_source_changed()
; CHECK: %r = call i64 @sum_all(%S* %dst)
; RESULT-LABEL: define i64 @full_array_source_changed()
; RESULT-NEXT: ret i64 15
define i64 @full_array_source_changed() {
  %src = alloca %S, i64 2, align 8
  %dst = alloca %S, i64 2, align 8
  %a = getelementptr inbounds %S, %S* %src, i64 0, i32 0
  %b = getelementptr inbounds %S, %S* %src, i64 0, i32 1
  %c = getelementptr inbounds %S, %S* %src, i64 1, i32 0
  %e = getelementptr inbounds %S, %S* %src, i64 1, i32 1
  store i64 1, i64* %a, align 8
  store i64 2, i64* %b, align 8
  store i64 4, i64* %c, align 8
  store i64 8, i64* %e, align 8
  %s = bitcast %S* %src to i8*
  %d = bitcast %S* %dst to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d, i8* %s, i64 32, i1 false)
  store i64 9, i64* %c, align 8
  %r = call i64 @sum_all(%S* %dst)
  ret i64 %r
}

; Destination propagation also needs the full current allocation, even when
; an earlier copy covers the entire source allocation.
; CHECK-LABEL: define i64 @partial_array_destination_propagation()
; CHECK: %r = call i64 @sum_all_dest(%S* %late)
; RESULT-LABEL: define i64 @partial_array_destination_propagation()
; RESULT-NEXT: ret i64 15
define i64 @partial_array_destination_propagation() {
  %src = alloca %S, i64 2, align 8
  %early = alloca %S, i64 2, align 8
  %late = alloca %S, i64 2, align 8
  %a = getelementptr inbounds %S, %S* %src, i64 0, i32 0
  %b = getelementptr inbounds %S, %S* %src, i64 0, i32 1
  %c = getelementptr inbounds %S, %S* %src, i64 1, i32 0
  %e = getelementptr inbounds %S, %S* %src, i64 1, i32 1
  store i64 1, i64* %a, align 8
  store i64 2, i64* %b, align 8
  store i64 40, i64* %c, align 8
  store i64 80, i64* %e, align 8
  %lc = getelementptr inbounds %S, %S* %late, i64 1, i32 0
  %le = getelementptr inbounds %S, %S* %late, i64 1, i32 1
  store i64 4, i64* %lc, align 8
  store i64 8, i64* %le, align 8
  %s = bitcast %S* %src to i8*
  %d0 = bitcast %S* %early to i8*
  %d1 = bitcast %S* %late to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d0, i8* %s, i64 32, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d1, i8* %s, i64 16, i1 false)
  %r = call i64 @sum_all_dest(%S* %late)
  ret i64 %r
}

; Unknown destination allocation counts cannot be proved fully equivalent.
; These have legal concrete instances with n >= 2.
; CHECK-LABEL: define i64 @unknown_source_destination_count(
; CHECK: %r = call i64 @sum_all(%S* %dst)
define i64 @unknown_source_destination_count(i64 %n) {
  %src = alloca %S, i64 2, align 8
  %dst = alloca %S, i64 %n, align 8
  %a = getelementptr inbounds %S, %S* %src, i64 0, i32 0
  %b = getelementptr inbounds %S, %S* %src, i64 0, i32 1
  %c = getelementptr inbounds %S, %S* %src, i64 1, i32 0
  %e = getelementptr inbounds %S, %S* %src, i64 1, i32 1
  store i64 1, i64* %a, align 8
  store i64 2, i64* %b, align 8
  store i64 4, i64* %c, align 8
  store i64 8, i64* %e, align 8
  %s = bitcast %S* %src to i8*
  %d = bitcast %S* %dst to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d, i8* %s, i64 32, i1 false)
  %r = call i64 @sum_all(%S* %dst)
  ret i64 %r
}

; CHECK-LABEL: define i64 @unknown_destination_propagation_count(
; CHECK: %r = call i64 @sum_all_dest(%S* %dst)
define i64 @unknown_destination_propagation_count(i64 %n) {
  %src = alloca %S, i64 2, align 8
  %dst = alloca %S, i64 %n, align 8
  %a = getelementptr inbounds %S, %S* %src, i64 0, i32 0
  %b = getelementptr inbounds %S, %S* %src, i64 0, i32 1
  %c = getelementptr inbounds %S, %S* %src, i64 1, i32 0
  %e = getelementptr inbounds %S, %S* %src, i64 1, i32 1
  store i64 1, i64* %a, align 8
  store i64 2, i64* %b, align 8
  store i64 4, i64* %c, align 8
  store i64 8, i64* %e, align 8
  %s = bitcast %S* %src to i8*
  %d = bitcast %S* %dst to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d, i8* %s, i64 32, i1 false)
  %r = call i64 @sum_all_dest(%S* %dst)
  ret i64 %r
}

attributes #0 = { alwaysinline nounwind readonly willreturn }
attributes #1 = { alwaysinline argmemonly nounwind willreturn }
