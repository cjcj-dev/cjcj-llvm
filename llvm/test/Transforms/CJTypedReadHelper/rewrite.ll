; RUN: opt -passes=cj-typed-read-helper -S < %s | FileCheck %s
; RUN: opt '-passes=default<O0>' --cangjie-pipeline -S < %s | \
; RUN:   FileCheck %s --check-prefix=PIPELINE

%RefPayload = type { i8 addrspace(1)* }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }
@RefPayload.ti = external global %TypeInfo, !RelatedType !0

define void @typed_read(i8 addrspace(1)* %unused) gc "cangjie" {
entry:
  %object = call i8 addrspace(1)* @llvm.cj.alloca.generic(
      i8* bitcast (%TypeInfo* @RefPayload.ti to i8*), i32 8)
  %carrier = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.raw = getelementptr i8*, i8* addrspace(1)* %carrier, i32 1
  %payload = bitcast i8* addrspace(1)* %payload.raw to i8 addrspace(1)*
  %dst.object = alloca %RefPayload, align 8
  %dst = bitcast %RefPayload* %dst.object to i8*
  call void @llvm.cj.memset(i8* %dst, i8 0, i64 8, i1 false)
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst, i8 addrspace(1)* %payload,
                                       i64 8, i1 false)
  ret void
}

define void @typed_managed_read() gc "cangjie" {
entry:
  %object = call i8 addrspace(1)* @managed()
  %carrier = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.raw = getelementptr i8*, i8* addrspace(1)* %carrier, i32 1
  %typed = bitcast i8* addrspace(1)* %payload.raw to %RefPayload addrspace(1)*
  %payload = bitcast %RefPayload addrspace(1)* %typed to i8 addrspace(1)*
  %dst.object = alloca %RefPayload, align 8
  %dst = bitcast %RefPayload* %dst.object to i8*
  call void @llvm.cj.memset(i8* %dst, i8 0, i64 8, i1 false)
  call void @llvm.memcpy.p0i8.p1i8.i64(
      i8* %dst, i8 addrspace(1)* %payload, i64 8, i1 false)
  ret void
}

declare i8 addrspace(1)* @managed() gc "cangjie"
declare i8 addrspace(1)* @llvm.cj.alloca.generic(i8*, i32)
declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
!0 = !{!"RefPayload"}

; CHECK-LABEL: define void @typed_read
; CHECK: call void @llvm.cj.gcread.struct.i64(i8* %dst, i8 addrspace(1)* %object, i8 addrspace(1)* %payload, i64 8)
; CHECK-NOT: call void @llvm.memcpy
; CHECK-LABEL: define void @typed_managed_read
; CHECK: call void @llvm.cj.gcread.struct.i64(i8* %dst, i8 addrspace(1)* %object, i8 addrspace(1)* %payload, i64 8)
; CHECK-NOT: call void @llvm.memcpy
; PIPELINE-LABEL: define void @typed_read
; PIPELINE: call i8 addrspace(1)* @llvm.cj.gcread.ref
; PIPELINE-NOT: call void @llvm.memcpy
; PIPELINE-LABEL: define void @typed_managed_read
; PIPELINE: call i8 addrspace(1)* @llvm.cj.gcread.ref
; PIPELINE-NOT: call void @llvm.memcpy
