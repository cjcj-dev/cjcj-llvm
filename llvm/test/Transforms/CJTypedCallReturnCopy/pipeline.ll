; RUN: opt -passes='default<O0>' --cangjie-pipeline -S < %s | FileCheck %s --check-prefix=PIPELINE
; RUN: opt -passes='cj-typed-call-return-copy,cj-ir-verifier,cj-barrier-split' -S < %s | FileCheck %s --check-prefix=SPLIT

target datalayout = "e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
%Plain = type { i8*, i64 }

; PIPELINE-LABEL: define void @materialize_native_plain(
; PIPELINE: call void @llvm.cj.copy.no.ref.struct.i64({{.*}}), !AggType ![[PLAIN:[0-9]+]]
; PIPELINE-NOT: call void @llvm.memcpy
; SPLIT-LABEL: define void @materialize_native_plain(
; SPLIT: call void @llvm.cj.copy.no.ref.struct.i64({{.*}}), !AggType ![[PLAIN:[0-9]+]]
; SPLIT-NOT: call void @llvm.memcpy
define void @materialize_native_plain() gc "cangjie" {
entry:
  %dst = alloca %Plain, align 8
  %native = call i8* @native_plain()
  %typed = bitcast i8* %native to %Plain*
  %zero = getelementptr inbounds %Plain, %Plain* %typed, i64 0
  %dst.bytes = bitcast %Plain* %dst to i8*
  %src.bytes = bitcast %Plain* %zero to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* align 8 %dst.bytes,
      i8* align 8 %src.bytes, i64 16, i1 false)
  ret void
}

declare i8* @native_plain() #0
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
attributes #0 = { "cj2c" }

; PIPELINE: ![[PLAIN]] = !{!"Plain"}
; SPLIT: ![[PLAIN]] = !{!"Plain"}
