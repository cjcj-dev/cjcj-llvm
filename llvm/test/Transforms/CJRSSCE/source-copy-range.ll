; RUN: opt -opaque-pointers=0 -passes=cj-rssce -S < %s | FileCheck %s --check-prefixes=CHECK,TYPED
; RUN: opt -opaque-pointers=1 -passes=cj-rssce -S < %s | FileCheck %s --check-prefixes=CHECK,OPAQUE
; RUN: opt -opaque-pointers=0 -passes='function(cj-rssce),always-inline,function(sroa,instcombine,simplifycfg)' -S < %s | FileCheck %s --check-prefix=RESULT
; RUN: opt -opaque-pointers=1 -passes='function(cj-rssce),always-inline,function(sroa,instcombine,simplifycfg)' -S < %s | FileCheck %s --check-prefix=RESULT
;
; Check the actual replacement address and the value read by the consumer.
; A struct pointee type bounds neither an alloca array nor a memcpy's source.
; @sum deliberately has no nocapture parameter attribute: these cases exercise
; source propagation, without destination propagation concealing its result.

target datalayout = "e-p:64:64-i64:64-n8:16:32:64-S128"

%S = type { i64, i64 }
%H = type { i64 }

declare void @llvm.memcpy.p0i8.p0i8.i64(i8* noalias nocapture writeonly, i8* noalias nocapture readonly, i64, i1 immarg)

define internal i64 @sum(%S* %p) #0 {
  %a = getelementptr inbounds %S, %S* %p, i64 0, i32 0
  %b = getelementptr inbounds %S, %S* %p, i64 0, i32 1
  %x = load i64, i64* %a, align 8
  %y = load i64, i64* %b, align 8
  %r = add i64 %x, %y
  ret i64 %r
}

; All accesses are within the 32-byte allocation. Replacing dst with src+16
; after the write would read {9,2}, returning 11 instead of 3.
; CHECK-LABEL: define i64 @second_element_changed()
; CHECK: %r = call i64 @sum({{%S\*|ptr}} %dst)
; RESULT-LABEL: define i64 @second_element_changed()
; RESULT-NEXT: ret i64 3
define i64 @second_element_changed() {
  %src = alloca %S, i64 2, align 8
  %dst = alloca %S, align 8
  %a = getelementptr inbounds %S, %S* %src, i64 1, i32 0
  %b = getelementptr inbounds %S, %S* %src, i64 1, i32 1
  store i64 1, i64* %a, align 8
  store i64 2, i64* %b, align 8
  %second = getelementptr inbounds %S, %S* %src, i64 1
  %s = bitcast %S* %second to i8*
  %d = bitcast %S* %dst to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d, i8* %s, i64 16, i1 false)
  store i64 9, i64* %a, align 8
  %r = call i64 @sum(%S* %dst)
  ret i64 %r
}

; Positive control: retain the optimization and its exact second-element ptr.
; CHECK-LABEL: define i64 @second_element_clean()
; TYPED: [[BASE:%.*]] = bitcast %S* %src to i8*
; TYPED-NEXT: [[RANGE:%.*]] = getelementptr inbounds i8, i8* [[BASE]], i32 16
; TYPED: [[ARG:%.*]] = bitcast i8* [[RANGE]] to %S*
; TYPED-NEXT: %r = call i64 @sum(%S* [[ARG]])
; OPAQUE: [[RANGE:%.*]] = getelementptr inbounds i8, ptr %src, i32 16
; OPAQUE: %r = call i64 @sum(ptr [[RANGE]])
; RESULT-LABEL: define i64 @second_element_clean()
; RESULT-NEXT: ret i64 3
define i64 @second_element_clean() {
  %src = alloca %S, i64 2, align 8
  %dst = alloca %S, align 8
  %a = getelementptr inbounds %S, %S* %src, i64 1, i32 0
  %b = getelementptr inbounds %S, %S* %src, i64 1, i32 1
  store i64 1, i64* %a, align 8
  store i64 2, i64* %b, align 8
  %second = getelementptr inbounds %S, %S* %src, i64 1
  %s = bitcast %S* %second to i8*
  %d = bitcast %S* %dst to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d, i8* %s, i64 16, i1 false)
  %r = call i64 @sum(%S* %dst)
  ret i64 %r
}

; A write to element zero must not invalidate the copy of element one.
; CHECK-LABEL: define i64 @second_element_disjoint_write()
; TYPED: [[BASE:%.*]] = bitcast %S* %src to i8*
; TYPED-NEXT: [[RANGE:%.*]] = getelementptr inbounds i8, i8* [[BASE]], i32 16
; TYPED: [[ARG:%.*]] = bitcast i8* [[RANGE]] to %S*
; TYPED-NEXT: %r = call i64 @sum(%S* [[ARG]])
; OPAQUE: [[RANGE:%.*]] = getelementptr inbounds i8, ptr %src, i32 16
; OPAQUE: %r = call i64 @sum(ptr [[RANGE]])
; RESULT-LABEL: define i64 @second_element_disjoint_write()
; RESULT-NEXT: ret i64 3
define i64 @second_element_disjoint_write() {
  %src = alloca %S, i64 2, align 8
  %dst = alloca %S, align 8
  %a = getelementptr inbounds %S, %S* %src, i64 1, i32 0
  %b = getelementptr inbounds %S, %S* %src, i64 1, i32 1
  store i64 1, i64* %a, align 8
  store i64 2, i64* %b, align 8
  %second = getelementptr inbounds %S, %S* %src, i64 1
  %s = bitcast %S* %second to i8*
  %d = bitcast %S* %dst to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d, i8* %s, i64 16, i1 false)
  %first = getelementptr inbounds %S, %S* %src, i64 0, i32 0
  store i64 9, i64* %first, align 8
  %r = call i64 @sum(%S* %dst)
  ret i64 %r
}

; The allocation count is unknown; the transfer still has an exact range.
; The caller supplies n >= 2.
; CHECK-LABEL: define i64 @dynamic_count_changed(
; CHECK: %r = call i64 @sum({{%S\*|ptr}} %dst)
define i64 @dynamic_count_changed(i64 %n) {
  %src = alloca %S, i64 %n, align 8
  %dst = alloca %S, align 8
  %a = getelementptr inbounds %S, %S* %src, i64 1, i32 0
  %b = getelementptr inbounds %S, %S* %src, i64 1, i32 1
  store i64 1, i64* %a, align 8
  store i64 2, i64* %b, align 8
  %second = getelementptr inbounds %S, %S* %src, i64 1
  %s = bitcast %S* %second to i8*
  %d = bitcast %S* %dst to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d, i8* %s, i64 16, i1 false)
  store i64 9, i64* %a, align 8
  %r = call i64 @sum(%S* %dst)
  ret i64 %r
}

; Unknown source/destination offset relation: keep the existing conservative
; address-analysis gate. The caller supplies offset = 16.
; CHECK-LABEL: define i64 @unknown_offset_changed(
; CHECK: %r = call i64 @sum({{%S\*|ptr}} %dst)
define i64 @unknown_offset_changed(i64 %offset) {
  %src = alloca %S, i64 2, align 8
  %dst = alloca %S, align 8
  %base = bitcast %S* %src to i8*
  %s = getelementptr inbounds i8, i8* %base, i64 %offset
  %element = bitcast i8* %s to %S*
  %a = getelementptr inbounds %S, %S* %element, i64 0, i32 0
  %b = getelementptr inbounds %S, %S* %element, i64 0, i32 1
  store i64 1, i64* %a, align 8
  store i64 2, i64* %b, align 8
  %d = bitcast %S* %dst to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d, i8* %s, i64 16, i1 false)
  store i64 9, i64* %a, align 8
  %r = call i64 @sum(%S* %dst)
  ret i64 %r
}

; Unknown copy size must not be guessed from the pointee type.
; The caller supplies length = 16.
; CHECK-LABEL: define i64 @unknown_length(
; CHECK: %r = call i64 @sum({{%S\*|ptr}} %dst)
define i64 @unknown_length(i64 %length) {
  %src = alloca %S, i64 2, align 8
  %dst = alloca %S, align 8
  %a = getelementptr inbounds %S, %S* %src, i64 1, i32 0
  %b = getelementptr inbounds %S, %S* %src, i64 1, i32 1
  store i64 1, i64* %a, align 8
  store i64 2, i64* %b, align 8
  %second = getelementptr inbounds %S, %S* %src, i64 1
  %s = bitcast %S* %second to i8*
  %d = bitcast %S* %dst to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d, i8* %s, i64 %length, i1 false)
  store i64 9, i64* %a, align 8
  %r = call i64 @sum(%S* %dst)
  ret i64 %r
}

; Both 8-byte sources must be queried when their copies jointly cover dst.
; CHECK-LABEL: define i64 @split_copy_changed()
; CHECK: %r = call i64 @sum({{%S\*|ptr}} %dst)
; RESULT-LABEL: define i64 @split_copy_changed()
; RESULT-NEXT: ret i64 3
define i64 @split_copy_changed() {
  %src = alloca %S, i64 2, align 8
  %dst = alloca %S, align 8
  %a = getelementptr inbounds %S, %S* %src, i64 1, i32 0
  %b = getelementptr inbounds %S, %S* %src, i64 1, i32 1
  store i64 1, i64* %a, align 8
  store i64 2, i64* %b, align 8
  %s0 = bitcast i64* %a to i8*
  %s1 = bitcast i64* %b to i8*
  %d0 = bitcast %S* %dst to i8*
  %db = getelementptr inbounds %S, %S* %dst, i64 0, i32 1
  %d1 = bitcast i64* %db to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d0, i8* %s0, i64 8, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d1, i8* %s1, i64 8, i1 false)
  store i64 9, i64* %a, align 8
  %r = call i64 @sum(%S* %dst)
  ret i64 %r
}

; The second source query matters independently of the first source query.
; CHECK-LABEL: define i64 @split_copy_tail_changed()
; CHECK: %r = call i64 @sum({{%S\*|ptr}} %dst)
; RESULT-LABEL: define i64 @split_copy_tail_changed()
; RESULT-NEXT: ret i64 3
define i64 @split_copy_tail_changed() {
  %src = alloca %S, i64 2, align 8
  %dst = alloca %S, align 8
  %a = getelementptr inbounds %S, %S* %src, i64 1, i32 0
  %b = getelementptr inbounds %S, %S* %src, i64 1, i32 1
  store i64 1, i64* %a, align 8
  store i64 2, i64* %b, align 8
  %s0 = bitcast i64* %a to i8*
  %s1 = bitcast i64* %b to i8*
  %d0 = bitcast %S* %dst to i8*
  %db = getelementptr inbounds %S, %S* %dst, i64 0, i32 1
  %d1 = bitcast i64* %db to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d0, i8* %s0, i64 8, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d1, i8* %s1, i64 8, i1 false)
  store i64 9, i64* %b, align 8
  %r = call i64 @sum(%S* %dst)
  ret i64 %r
}

; Single-element control: a write within the one copied struct still blocks.
; CHECK-LABEL: define i64 @single_element_changed()
; CHECK: %r = call i64 @sum({{%S\*|ptr}} %dst)
; RESULT-LABEL: define i64 @single_element_changed()
; RESULT-NEXT: ret i64 3
define i64 @single_element_changed() {
  %src = alloca %S, align 8
  %dst = alloca %S, align 8
  %a = getelementptr inbounds %S, %S* %src, i64 0, i32 0
  %b = getelementptr inbounds %S, %S* %src, i64 0, i32 1
  store i64 1, i64* %a, align 8
  store i64 2, i64* %b, align 8
  %s = bitcast %S* %src to i8*
  %d = bitcast %S* %dst to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d, i8* %s, i64 16, i1 false)
  store i64 9, i64* %a, align 8
  %r = call i64 @sum(%S* %dst)
  ret i64 %r
}

; Each range starts at its own copy, rather than at the last copy of dst.
; CHECK-LABEL: define i64 @split_copy_interleaved_write()
; CHECK: %r = call i64 @sum({{%S\*|ptr}} %dst)
; RESULT-LABEL: define i64 @split_copy_interleaved_write()
; RESULT-NEXT: ret i64 3
define i64 @split_copy_interleaved_write() {
  %src = alloca %S, i64 2, align 8
  %dst = alloca %S, align 8
  %a = getelementptr inbounds %S, %S* %src, i64 1, i32 0
  %b = getelementptr inbounds %S, %S* %src, i64 1, i32 1
  store i64 1, i64* %a, align 8
  store i64 2, i64* %b, align 8
  %s0 = bitcast i64* %a to i8*
  %s1 = bitcast i64* %b to i8*
  %d0 = bitcast %S* %dst to i8*
  %db = getelementptr inbounds %S, %S* %dst, i64 0, i32 1
  %d1 = bitcast i64* %db to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d0, i8* %s0, i64 8, i1 false)
  store i64 9, i64* %a, align 8
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d1, i8* %s1, i64 8, i1 false)
  %r = call i64 @sum(%S* %dst)
  ret i64 %r
}

; Unknown allocation count alone does not prevent exact-range propagation.
; The caller supplies n >= 2.
; CHECK-LABEL: define i64 @dynamic_count_clean(
; TYPED: [[BASE:%.*]] = bitcast %S* %src to i8*
; TYPED-NEXT: [[RANGE:%.*]] = getelementptr inbounds i8, i8* [[BASE]], i32 16
; TYPED: [[ARG:%.*]] = bitcast i8* [[RANGE]] to %S*
; TYPED-NEXT: %r = call i64 @sum(%S* [[ARG]])
; OPAQUE: [[RANGE:%.*]] = getelementptr inbounds i8, ptr %src, i32 16
; OPAQUE: %r = call i64 @sum(ptr [[RANGE]])
define i64 @dynamic_count_clean(i64 %n) {
  %src = alloca %S, i64 %n, align 8
  %dst = alloca %S, align 8
  %a = getelementptr inbounds %S, %S* %src, i64 1, i32 0
  %b = getelementptr inbounds %S, %S* %src, i64 1, i32 1
  store i64 1, i64* %a, align 8
  store i64 2, i64* %b, align 8
  %second = getelementptr inbounds %S, %S* %src, i64 1
  %s = bitcast %S* %second to i8*
  %d = bitcast %S* %dst to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d, i8* %s, i64 16, i1 false)
  %r = call i64 @sum(%S* %dst)
  ret i64 %r
}

; A write whose offset is unknown may overlap the known copy source range.
; The caller supplies an aligned offset within the allocation, e.g. 16.
; CHECK-LABEL: define i64 @may_alias_source_write(
; CHECK: %r = call i64 @sum({{%S\*|ptr}} %dst)
define i64 @may_alias_source_write(i64 %offset) {
  %src = alloca %S, i64 2, align 8
  %dst = alloca %S, align 8
  %a = getelementptr inbounds %S, %S* %src, i64 1, i32 0
  %b = getelementptr inbounds %S, %S* %src, i64 1, i32 1
  store i64 1, i64* %a, align 8
  store i64 2, i64* %b, align 8
  %second = getelementptr inbounds %S, %S* %src, i64 1
  %s = bitcast %S* %second to i8*
  %d = bitcast %S* %dst to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d, i8* %s, i64 16, i1 false)
  %base = bitcast %S* %src to i8*
  %where = getelementptr inbounds i8, i8* %base, i64 %offset
  %write = bitcast i8* %where to i64*
  store i64 9, i64* %write, align 8
  %r = call i64 @sum(%S* %dst)
  ret i64 %r
}

; A partial transfer does not by itself cover the whole destination struct.
; CHECK-LABEL: define i64 @partial_copy()
; CHECK: %r = call i64 @sum({{%S\*|ptr}} %dst)
; RESULT-LABEL: define i64 @partial_copy()
; RESULT-NEXT: ret i64 3
define i64 @partial_copy() {
  %src = alloca %S, i64 2, align 8
  %dst = alloca %S, align 8
  %a = getelementptr inbounds %S, %S* %src, i64 1, i32 0
  store i64 1, i64* %a, align 8
  %db = getelementptr inbounds %S, %S* %dst, i64 0, i32 1
  store i64 2, i64* %db, align 8
  %s = bitcast i64* %a to i8*
  %d = bitcast %S* %dst to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d, i8* %s, i64 8, i1 false)
  store i64 9, i64* %a, align 8
  %r = call i64 @sum(%S* %dst)
  ret i64 %r
}

define internal i64 @read_half(%H* %p) #0 {
  %a = getelementptr inbounds %H, %H* %p, i64 0, i32 0
  %r = load i64, i64* %a, align 8
  ret i64 %r
}

; The actual copy length is 8, even though the source alloca element is 16.
; A write to its other field must not invalidate the copied field.
; CHECK-LABEL: define i64 @short_copy_disjoint_write()
; TYPED: [[BASE:%.*]] = bitcast %S* %src to i8*
; TYPED-NEXT: [[RANGE:%.*]] = getelementptr inbounds i8, i8* [[BASE]], i32 8
; TYPED: [[ARG:%.*]] = bitcast i8* [[RANGE]] to %H*
; TYPED-NEXT: %r = call i64 @read_half(%H* [[ARG]])
; OPAQUE: [[RANGE:%.*]] = getelementptr inbounds i8, ptr %src, i32 8
; OPAQUE: %r = call i64 @read_half(ptr [[RANGE]])
; RESULT-LABEL: define i64 @short_copy_disjoint_write()
; RESULT-NEXT: ret i64 2
define i64 @short_copy_disjoint_write() {
  %src = alloca %S, align 8
  %dst = alloca %H, align 8
  %a = getelementptr inbounds %S, %S* %src, i64 0, i32 0
  %b = getelementptr inbounds %S, %S* %src, i64 0, i32 1
  store i64 1, i64* %a, align 8
  store i64 2, i64* %b, align 8
  %s = bitcast i64* %b to i8*
  %d = bitcast %H* %dst to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %d, i8* %s, i64 8, i1 false)
  store i64 9, i64* %a, align 8
  %r = call i64 @read_half(%H* %dst)
  ret i64 %r
}

attributes #0 = { alwaysinline nounwind readonly willreturn }
