; RUN: opt -passes=cj-typed-call-return-copy -S < %s | FileCheck %s

target datalayout = "e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"

%Plain = type { i8*, i64 }
%Other = type { i64, i64 }
%WithRef = type { i8 addrspace(1)*, i64 }

; CHECK-LABEL: define void @rewrite_cj2c_memcpy(
; CHECK: %native = call i8* @native_plain()
; CHECK: call void @llvm.cj.copy.no.ref.struct.i64(i8* align 8 %dst.bytes, i8* align 8 %src.bytes, i64 16), !AggType ![[PLAIN:[0-9]+]]
; CHECK-NOT: llvm.memcpy
define void @rewrite_cj2c_memcpy() gc "cangjie" {
entry:
  %dst = alloca %Plain, align 8
  %native = call i8* @native_plain()
  %typed = bitcast i8* %native to %Plain*
  %zero = getelementptr inbounds %Plain, %Plain* %typed, i64 0
  %dst.bytes = bitcast %Plain* %dst to i8*
  %src.bytes = bitcast %Plain* %zero to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* align 8 %dst.bytes,
                                       i8* align 8 %src.bytes,
                                       i64 16, i1 false)
  ret void
}

; Memmove has the same closed, whole-object admission shape.
; CHECK-LABEL: define void @rewrite_cj2c_memmove(
; CHECK: call void @llvm.cj.copy.no.ref.struct.i64({{.*}}), !AggType ![[PLAIN]]
; CHECK-NOT: llvm.memmove
define void @rewrite_cj2c_memmove() gc "cangjie" {
entry:
  %dst = alloca %Plain, align 8
  %native = call i8* @native_plain()
  %typed = bitcast i8* %native to %Plain*
  %zero = getelementptr inbounds %Plain, %Plain* %typed, i64 0
  %dst.bytes = bitcast %Plain* %dst to i8*
  %src.bytes = bitcast %Plain* %zero to i8*
  call void @llvm.memmove.p0i8.p0i8.i64(i8* align 8 %dst.bytes,
                                        i8* align 8 %src.bytes,
                                        i64 16, i1 false)
  ret void
}

; CHECK-LABEL: define void @keep_without_cj2c(
; CHECK: call void @llvm.memcpy.p0i8.p0i8.i64
; CHECK-NOT: call void @llvm.cj.copy.no.ref.struct
define void @keep_without_cj2c() gc "cangjie" {
entry:
  %dst = alloca %Plain, align 8
  %native = call i8* @language_plain()
  %typed = bitcast i8* %native to %Plain*
  %zero = getelementptr inbounds %Plain, %Plain* %typed, i64 0
  %dst.bytes = bitcast %Plain* %dst to i8*
  %src.bytes = bitcast %Plain* %zero to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.bytes, i8* %src.bytes,
                                       i64 16, i1 false)
  ret void
}

; CHECK-LABEL: define void @keep_as1_field(
; CHECK: call void @llvm.memcpy.p0i8.p0i8.i64
; CHECK-NOT: call void @llvm.cj.copy.no.ref.struct
define void @keep_as1_field() gc "cangjie" {
entry:
  %dst = alloca %WithRef, align 8
  %native = call i8* @native_ref()
  %typed = bitcast i8* %native to %WithRef*
  %zero = getelementptr inbounds %WithRef, %WithRef* %typed, i64 0
  %dst.bytes = bitcast %WithRef* %dst to i8*
  %src.bytes = bitcast %WithRef* %zero to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.bytes, i8* %src.bytes,
                                       i64 16, i1 false)
  ret void
}

; CHECK-LABEL: define void @keep_size_mismatch(
; CHECK: call void @llvm.memcpy.p0i8.p0i8.i64({{.*}}i64 8
; CHECK-NOT: call void @llvm.cj.copy.no.ref.struct
define void @keep_size_mismatch() gc "cangjie" {
entry:
  %dst = alloca %Plain, align 8
  %native = call i8* @native_plain()
  %typed = bitcast i8* %native to %Plain*
  %zero = getelementptr inbounds %Plain, %Plain* %typed, i64 0
  %dst.bytes = bitcast %Plain* %dst to i8*
  %src.bytes = bitcast %Plain* %zero to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.bytes, i8* %src.bytes,
                                       i64 8, i1 false)
  ret void
}

; CHECK-LABEL: define void @keep_nonzero_source_gep(
; CHECK: call void @llvm.memcpy.p0i8.p0i8.i64
; CHECK-NOT: call void @llvm.cj.copy.no.ref.struct
define void @keep_nonzero_source_gep() gc "cangjie" {
entry:
  %dst = alloca %Plain, align 8
  %native = call i8* @native_plain()
  %typed = bitcast i8* %native to %Plain*
  %one = getelementptr inbounds %Plain, %Plain* %typed, i64 1
  %dst.bytes = bitcast %Plain* %dst to i8*
  %src.bytes = bitcast %Plain* %one to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.bytes, i8* %src.bytes,
                                       i64 16, i1 false)
  ret void
}

; CHECK-LABEL: define void @keep_dynamic_source_gep(
; CHECK: call void @llvm.memcpy.p0i8.p0i8.i64
; CHECK-NOT: call void @llvm.cj.copy.no.ref.struct
define void @keep_dynamic_source_gep(i64 %index) gc "cangjie" {
entry:
  %dst = alloca %Plain, align 8
  %native = call i8* @native_plain()
  %typed = bitcast i8* %native to %Plain*
  %element = getelementptr inbounds %Plain, %Plain* %typed, i64 %index
  %dst.bytes = bitcast %Plain* %dst to i8*
  %src.bytes = bitcast %Plain* %element to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.bytes, i8* %src.bytes,
                                       i64 16, i1 false)
  ret void
}

; CHECK-LABEL: define void @keep_different_destination_type(
; CHECK: call void @llvm.memcpy.p0i8.p0i8.i64
; CHECK-NOT: call void @llvm.cj.copy.no.ref.struct
define void @keep_different_destination_type() gc "cangjie" {
entry:
  %dst = alloca %Other, align 8
  %native = call i8* @native_plain()
  %typed = bitcast i8* %native to %Plain*
  %zero = getelementptr inbounds %Plain, %Plain* %typed, i64 0
  %dst.bytes = bitcast %Other* %dst to i8*
  %src.bytes = bitcast %Plain* %zero to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.bytes, i8* %src.bytes,
                                       i64 16, i1 false)
  ret void
}

; CHECK-LABEL: define void @keep_nonentry_destination(
; CHECK: call void @llvm.memcpy.p0i8.p0i8.i64
; CHECK-NOT: call void @llvm.cj.copy.no.ref.struct
define void @keep_nonentry_destination(i1 %condition) gc "cangjie" {
entry:
  br i1 %condition, label %copy, label %done
copy:
  %dst = alloca %Plain, align 8
  %native = call i8* @native_plain()
  %typed = bitcast i8* %native to %Plain*
  %zero = getelementptr inbounds %Plain, %Plain* %typed, i64 0
  %dst.bytes = bitcast %Plain* %dst to i8*
  %src.bytes = bitcast %Plain* %zero to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.bytes, i8* %src.bytes,
                                       i64 16, i1 false)
  br label %done
done:
  ret void
}

; CHECK-LABEL: define void @keep_nonzero_destination_offset(
; CHECK: call void @llvm.memcpy.p0i8.p0i8.i64
; CHECK-NOT: call void @llvm.cj.copy.no.ref.struct
define void @keep_nonzero_destination_offset() gc "cangjie" {
entry:
  %dst = alloca [2 x %Plain], align 8
  %dst.one = getelementptr inbounds [2 x %Plain], [2 x %Plain]* %dst,
                                      i64 0, i64 1
  %native = call i8* @native_plain()
  %typed = bitcast i8* %native to %Plain*
  %zero = getelementptr inbounds %Plain, %Plain* %typed, i64 0
  %dst.bytes = bitcast %Plain* %dst.one to i8*
  %src.bytes = bitcast %Plain* %zero to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.bytes, i8* %src.bytes,
                                       i64 16, i1 false)
  ret void
}

; CHECK-LABEL: define void @keep_call_as_destination(
; CHECK: call void @llvm.memcpy.p0i8.p0i8.i64
; CHECK-NOT: call void @llvm.cj.copy.no.ref.struct
define void @keep_call_as_destination() gc "cangjie" {
entry:
  %src = alloca %Plain, align 8
  %native = call i8* @native_plain()
  %typed = bitcast i8* %native to %Plain*
  %zero = getelementptr inbounds %Plain, %Plain* %typed, i64 0
  %dst.bytes = bitcast %Plain* %zero to i8*
  %src.bytes = bitcast %Plain* %src to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.bytes, i8* %src.bytes,
                                       i64 16, i1 false)
  ret void
}

declare i8* @native_plain() #0
declare i8* @native_ref() #0
declare i8* @language_plain()
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
declare void @llvm.memmove.p0i8.p0i8.i64(i8*, i8*, i64, i1)

attributes #0 = { "cj2c" }

; CHECK: ![[PLAIN]] = !{!"Plain"}
