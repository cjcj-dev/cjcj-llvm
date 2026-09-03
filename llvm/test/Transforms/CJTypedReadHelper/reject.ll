; RUN: opt -passes=cj-typed-read-helper -S < %s | FileCheck %s

%RefPayload = type { i8 addrspace(1)* }
%OtherPayload = type { i8 addrspace(1)* }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }
@RefPayload.ti = external global %TypeInfo, !RelatedType !0

define void @reject_dynamic(i8 addrspace(1)* %src, i64 %n) gc "cangjie" {
entry:
  %dst.object = alloca %RefPayload, align 8
  %dst = bitcast %RefPayload* %dst.object to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst, i8 addrspace(1)* %src,
                                       i64 %n, i1 false)
  ret void
}

define void @reject_non_entry(i8 addrspace(1)* %src) gc "cangjie" {
entry:
  br label %body
body:
  %dst.object = alloca %RefPayload, align 8
  %dst = bitcast %RefPayload* %dst.object to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst, i8 addrspace(1)* %src,
                                       i64 8, i1 false)
  ret void
}

define void @reject_mismatched_destination() gc "cangjie" {
entry:
  %object = call i8 addrspace(1)* @llvm.cj.alloca.generic(
      i8* bitcast (%TypeInfo* @RefPayload.ti to i8*), i32 8)
  %carrier = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.raw = getelementptr i8*, i8* addrspace(1)* %carrier, i32 1
  %payload = bitcast i8* addrspace(1)* %payload.raw to i8 addrspace(1)*
  %dst.object = alloca %OtherPayload, align 8
  %dst = bitcast %OtherPayload* %dst.object to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(
      i8* %dst, i8 addrspace(1)* %payload, i64 8, i1 false)
  ret void
}

define void @reject_managed_interior() gc "cangjie" {
entry:
  %object = call i8 addrspace(1)* @managed()
  %carrier = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %interior.raw = getelementptr i8*, i8* addrspace(1)* %carrier, i32 2
  %typed = bitcast i8* addrspace(1)* %interior.raw to %RefPayload addrspace(1)*
  %src = bitcast %RefPayload addrspace(1)* %typed to i8 addrspace(1)*
  %dst.object = alloca %RefPayload, align 8
  %dst = bitcast %RefPayload* %dst.object to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(
      i8* %dst, i8 addrspace(1)* %src, i64 8, i1 false)
  ret void
}

define void @reject_dynamic_allocation_size(i32 %allocation.size) gc "cangjie" {
entry:
  %object = call i8 addrspace(1)* @llvm.cj.alloca.generic(
      i8* bitcast (%TypeInfo* @RefPayload.ti to i8*), i32 %allocation.size)
  %carrier = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.raw = getelementptr i8*, i8* addrspace(1)* %carrier, i32 1
  %payload = bitcast i8* addrspace(1)* %payload.raw to i8 addrspace(1)*
  %dst.object = alloca %RefPayload, align 8
  %dst = bitcast %RefPayload* %dst.object to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(
      i8* %dst, i8 addrspace(1)* %payload, i64 8, i1 false)
  ret void
}

declare i8 addrspace(1)* @managed() gc "cangjie"
declare i8 addrspace(1)* @llvm.cj.alloca.generic(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
!0 = !{!"RefPayload"}

; CHECK-LABEL: define void @reject_dynamic
; CHECK: llvm.memcpy
; CHECK-LABEL: define void @reject_non_entry
; CHECK: llvm.memcpy
; CHECK-LABEL: define void @reject_mismatched_destination
; CHECK: llvm.memcpy
; CHECK-LABEL: define void @reject_managed_interior
; CHECK: llvm.memcpy
; CHECK-LABEL: define void @reject_dynamic_allocation_size
; CHECK: llvm.memcpy
