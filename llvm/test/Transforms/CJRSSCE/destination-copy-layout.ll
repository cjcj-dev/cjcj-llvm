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
define internal i64 @second(%W* nocapture readonly %p) #0 {
  %q = getelementptr inbounds %W, %W* %p, i64 1, i32 0
  %v = load i64, i64* %q, align 8
  ret i64 %v
}

; CHECK-LABEL: define i64 @candidate_gap()
; CHECK: %r = call i64 @second(%W* %late)
; RESULT-LABEL: define i64 @candidate_gap()
; RESULT-NEXT: ret i64 2
define i64 @candidate_gap() {
  %a = alloca %W, align 8
  %b = alloca %W, align 8
  %early = alloca %W, i64 3, align 8
  %late = alloca %W, i64 2, align 8
  %af = getelementptr inbounds %W, %W* %a, i64 0, i32 0
  %bf = getelementptr inbounds %W, %W* %b, i64 0, i32 0
  store i64 1, i64* %af, align 8
  store i64 2, i64* %bf, align 8
  %hole = getelementptr inbounds %W, %W* %early, i64 1, i32 0
  store i64 9, i64* %hole, align 8
  %ea = getelementptr inbounds %W, %W* %early, i64 0
  %eb = getelementptr inbounds %W, %W* %early, i64 2
  %l1 = getelementptr inbounds %W, %W* %late, i64 1
  %sa = bitcast %W* %a to i8*
  %sb = bitcast %W* %b to i8*
  %eab = bitcast %W* %ea to i8*
  %ebb = bitcast %W* %eb to i8*
  %l0b = bitcast %W* %late to i8*
  %l1b = bitcast %W* %l1 to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %eab, i8* %sa, i64 8, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %ebb, i8* %sb, i64 8, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %l0b, i8* %sa, i64 8, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %l1b, i8* %sb, i64 8, i1 false)
  %r = call i64 @second(%W* %late)
  ret i64 %r
}

; CHECK-LABEL: define i64 @candidate_shift_changes()
; CHECK: %r = call i64 @second(%W* %late)
; RESULT-LABEL: define i64 @candidate_shift_changes()
; RESULT-NEXT: ret i64 2
define i64 @candidate_shift_changes() {
  %a = alloca %W, align 8
  %b = alloca %W, align 8
  %early = alloca %W, i64 4, align 8
  %late = alloca %W, i64 2, align 8
  %af = getelementptr inbounds %W, %W* %a, i64 0, i32 0
  %bf = getelementptr inbounds %W, %W* %b, i64 0, i32 0
  store i64 1, i64* %af, align 8
  store i64 2, i64* %bf, align 8
  %hole = getelementptr inbounds %W, %W* %early, i64 2, i32 0
  store i64 9, i64* %hole, align 8
  %ea = getelementptr inbounds %W, %W* %early, i64 1
  %eb = getelementptr inbounds %W, %W* %early, i64 3
  %l1 = getelementptr inbounds %W, %W* %late, i64 1
  %sa = bitcast %W* %a to i8*
  %sb = bitcast %W* %b to i8*
  %eab = bitcast %W* %ea to i8*
  %ebb = bitcast %W* %eb to i8*
  %l0b = bitcast %W* %late to i8*
  %l1b = bitcast %W* %l1 to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %eab, i8* %sa, i64 8, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %ebb, i8* %sb, i64 8, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %l0b, i8* %sa, i64 8, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %l1b, i8* %sb, i64 8, i1 false)
  %r = call i64 @second(%W* %late)
  ret i64 %r
}

; CHECK-LABEL: define i64 @candidate_contiguous()
; CHECK: %r = call i64 @second(%W* %early)
; RESULT-LABEL: define i64 @candidate_contiguous()
; RESULT-NEXT: ret i64 2
define i64 @candidate_contiguous() {
  %a = alloca %W, align 8
  %b = alloca %W, align 8
  %early = alloca %W, i64 2, align 8
  %late = alloca %W, i64 2, align 8
  %af = getelementptr inbounds %W, %W* %a, i64 0, i32 0
  %bf = getelementptr inbounds %W, %W* %b, i64 0, i32 0
  store i64 1, i64* %af, align 8
  store i64 2, i64* %bf, align 8
  %ea = getelementptr inbounds %W, %W* %early, i64 0
  %eb = getelementptr inbounds %W, %W* %early, i64 1
  %l1 = getelementptr inbounds %W, %W* %late, i64 1
  %sa = bitcast %W* %a to i8*
  %sb = bitcast %W* %b to i8*
  %eab = bitcast %W* %ea to i8*
  %ebb = bitcast %W* %eb to i8*
  %l0b = bitcast %W* %late to i8*
  %l1b = bitcast %W* %l1 to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %eab, i8* %sa, i64 8, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %ebb, i8* %sb, i64 8, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %l0b, i8* %sa, i64 8, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %l1b, i8* %sb, i64 8, i1 false)
  %r = call i64 @second(%W* %late)
  ret i64 %r
}

; CHECK-LABEL: define i64 @candidate_shifted_window()
; CHECK: [[BYTE:%.*]] = bitcast %W* %early to i8*
; CHECK: [[WINDOW:%.*]] = getelementptr inbounds i8, i8* [[BYTE]], i64 8
; CHECK: [[ARG:%.*]] = bitcast i8* [[WINDOW]] to %W*
; CHECK: %r = call i64 @second(%W* [[ARG]])
; RESULT-LABEL: define i64 @candidate_shifted_window()
; RESULT-NEXT: ret i64 2
define i64 @candidate_shifted_window() {
  %a = alloca %W, align 8
  %b = alloca %W, align 8
  %early = alloca %W, i64 3, align 8
  %late = alloca %W, i64 2, align 8
  %af = getelementptr inbounds %W, %W* %a, i64 0, i32 0
  %bf = getelementptr inbounds %W, %W* %b, i64 0, i32 0
  store i64 1, i64* %af, align 8
  store i64 2, i64* %bf, align 8
  %ea = getelementptr inbounds %W, %W* %early, i64 1
  %eb = getelementptr inbounds %W, %W* %early, i64 2
  %l1 = getelementptr inbounds %W, %W* %late, i64 1
  %sa = bitcast %W* %a to i8*
  %sb = bitcast %W* %b to i8*
  %eab = bitcast %W* %ea to i8*
  %ebb = bitcast %W* %eb to i8*
  %l0b = bitcast %W* %late to i8*
  %l1b = bitcast %W* %l1 to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %eab, i8* %sa, i64 8, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %ebb, i8* %sb, i64 8, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %l0b, i8* %sa, i64 8, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %l1b, i8* %sb, i64 8, i1 false)
  %r = call i64 @second(%W* %late)
  ret i64 %r
}

attributes #0 = { alwaysinline argmemonly nounwind willreturn }
