; RUN: opt -passes=cj-typed-call-return-copy -S < %s | FileCheck %s

target datalayout = "e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
%Plain = type { i8*, i64 }
@sink = global i64 0

; CHECK-LABEL: define void @rewrite_unique_nonnull_path(
; CHECK: call void @llvm.cj.copy.no.ref.struct.i64({{.*}}), !AggType ![[PLAIN:[0-9]+]]
; CHECK-NOT: call void @llvm.memcpy
define void @rewrite_unique_nonnull_path() gc "cangjie" !dbg !2 {
entry:
  %dst = alloca %Plain, align 8
  %native = call i8* @native_plain()
  br label %check
check:
  %as.int = ptrtoint i8* %native to i64
  %is.null = icmp eq i64 %as.int, 0
  br label %condition
condition:
  br i1 %is.null, label %null, label %nonnull
null:
  ret void
nonnull:
  call void @llvm.dbg.declare(metadata %Plain* %dst, metadata !3,
                              metadata !DIExpression())
  br label %copy
copy:
  %typed = bitcast i8* %native to %Plain*
  %zero = getelementptr inbounds %Plain, %Plain* %typed, i64 0
  %dst.bytes = bitcast %Plain* %dst to i8*
  %src.bytes = bitcast %Plain* %zero to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* align 8 %dst.bytes,
      i8* align 8 %src.bytes, i64 16, i1 false)
  ret void
}

; CHECK-LABEL: define void @keep_intervening_call(
; CHECK: call void @opaque()
; CHECK: call void @llvm.memcpy.p0i8.p0i8.i64
; CHECK-NOT: call void @llvm.cj.copy.no.ref.struct
define void @keep_intervening_call() gc "cangjie" {
entry:
  %dst = alloca %Plain, align 8
  %native = call i8* @native_plain()
  %as.int = ptrtoint i8* %native to i64
  %is.null = icmp eq i64 %as.int, 0
  br i1 %is.null, label %done, label %nonnull
nonnull:
  call void @opaque()
  br label %copy
copy:
  %typed = bitcast i8* %native to %Plain*
  %zero = getelementptr %Plain, %Plain* %typed, i64 0
  %dst.bytes = bitcast %Plain* %dst to i8*
  %src.bytes = bitcast %Plain* %zero to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.bytes, i8* %src.bytes,
                                       i64 16, i1 false)
  br label %done
done:
  ret void
}

; Both null and non-null edges reach the copy block, which has a phi/merge.
; CHECK-LABEL: define void @keep_phi_merge(
; CHECK: %merged = phi i1
; CHECK: call void @llvm.memcpy.p0i8.p0i8.i64
; CHECK-NOT: call void @llvm.cj.copy.no.ref.struct
define void @keep_phi_merge() gc "cangjie" {
entry:
  %dst = alloca %Plain, align 8
  %native = call i8* @native_plain()
  %as.int = ptrtoint i8* %native to i64
  %is.null = icmp eq i64 %as.int, 0
  br i1 %is.null, label %null, label %nonnull
null:
  br label %copy
nonnull:
  br label %copy
copy:
  %merged = phi i1 [ true, %null ], [ false, %nonnull ]
  %typed = bitcast i8* %native to %Plain*
  %zero = getelementptr %Plain, %Plain* %typed, i64 0
  %dst.bytes = bitcast %Plain* %dst to i8*
  %src.bytes = bitcast %Plain* %zero to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.bytes, i8* %src.bytes,
                                       i64 16, i1 false)
  ret void
}

; CHECK-LABEL: define void @keep_condition_on_other_value(
; CHECK: br i1 %other
; CHECK: call void @llvm.memcpy.p0i8.p0i8.i64
; CHECK-NOT: call void @llvm.cj.copy.no.ref.struct
define void @keep_condition_on_other_value(i1 %other) gc "cangjie" {
entry:
  %dst = alloca %Plain, align 8
  %native = call i8* @native_plain()
  %as.int = ptrtoint i8* %native to i64
  %is.null = icmp eq i64 %as.int, 0
  br i1 %other, label %done, label %copy
copy:
  %typed = bitcast i8* %native to %Plain*
  %zero = getelementptr %Plain, %Plain* %typed, i64 0
  %dst.bytes = bitcast %Plain* %dst to i8*
  %src.bytes = bitcast %Plain* %zero to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.bytes, i8* %src.bytes,
                                       i64 16, i1 false)
  br label %done
done:
  ret void
}

; CHECK-LABEL: define void @keep_copy_on_null_edge(
; CHECK: call void @llvm.memcpy.p0i8.p0i8.i64
; CHECK-NOT: call void @llvm.cj.copy.no.ref.struct
define void @keep_copy_on_null_edge() gc "cangjie" {
entry:
  %dst = alloca %Plain, align 8
  %native = call i8* @native_plain()
  %as.int = ptrtoint i8* %native to i64
  %is.null = icmp eq i64 %as.int, 0
  br i1 %is.null, label %copy, label %done
copy:
  %typed = bitcast i8* %native to %Plain*
  %zero = getelementptr %Plain, %Plain* %typed, i64 0
  %dst.bytes = bitcast %Plain* %dst to i8*
  %src.bytes = bitcast %Plain* %zero to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.bytes, i8* %src.bytes,
                                       i64 16, i1 false)
  br label %done
done:
  ret void
}

; CHECK-LABEL: define void @keep_store_in_transparent_block(
; CHECK: store i64 1, i64* @sink
; CHECK: call void @llvm.memcpy.p0i8.p0i8.i64
; CHECK-NOT: call void @llvm.cj.copy.no.ref.struct
define void @keep_store_in_transparent_block() gc "cangjie" {
entry:
  %dst = alloca %Plain, align 8
  %native = call i8* @native_plain()
  %as.int = ptrtoint i8* %native to i64
  %is.null = icmp eq i64 %as.int, 0
  br i1 %is.null, label %done, label %nonnull
nonnull:
  store i64 1, i64* @sink
  br label %copy
copy:
  %typed = bitcast i8* %native to %Plain*
  %zero = getelementptr %Plain, %Plain* %typed, i64 0
  %dst.bytes = bitcast %Plain* %dst to i8*
  %src.bytes = bitcast %Plain* %zero to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.bytes, i8* %src.bytes,
                                       i64 16, i1 false)
  br label %done
done:
  ret void
}

declare i8* @native_plain() #0
declare void @opaque()
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
declare void @llvm.dbg.declare(metadata, metadata, metadata)

attributes #0 = { "cj2c" }

!llvm.dbg.cu = !{!0}
!0 = distinct !DICompileUnit(language: DW_LANG_C, file: !1,
    producer: "cj", isOptimized: false, runtimeVersion: 0,
    emissionKind: NoDebug)
!1 = !DIFile(filename: "null-check-cfg.cj", directory: ".")
!2 = distinct !DISubprogram(name: "rewrite_unique_nonnull_path", scope: !1,
    file: !1, line: 1, type: !4, scopeLine: 1,
    spFlags: DISPFlagDefinition, unit: !0)
!3 = !DILocalVariable(name: "dst", scope: !2, file: !1, line: 1,
    type: !5)
!4 = !DISubroutineType(types: !6)
!5 = !DIBasicType(name: "opaque", size: 128)
!6 = !{}

; CHECK: ![[PLAIN]] = !{!"Plain"}
