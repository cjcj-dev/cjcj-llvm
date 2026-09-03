; RUN: split-file %s %t
; RUN: not --crash opt '-passes=default<O0>' --cangjie-pipeline \
; RUN:   -disable-output < %t/mismatch-destination.ll 2>&1 | \
; RUN:   FileCheck %s --check-prefix=MISMATCH
; RUN: not --crash opt '-passes=default<O0>' --cangjie-pipeline \
; RUN:   -disable-output < %t/managed-interior.ll 2>&1 | \
; RUN:   FileCheck %s --check-prefix=INTERIOR

; MISMATCH: Bare memcpy/memmove of reference payload
; MISMATCH: in function mismatch_destination
; MISMATCH: LLVM ERROR: Broken function found, compilation aborted
; INTERIOR: Bare memcpy/memmove of reference payload
; INTERIOR: in function managed_interior
; INTERIOR: LLVM ERROR: Broken function found, compilation aborted

;--- mismatch-destination.ll
%RefPayload = type { i8 addrspace(1)* }
%OtherPayload = type { i8 addrspace(1)* }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }
@RefPayload.ti = external global %TypeInfo, !RelatedType !0

define void @mismatch_destination() gc "cangjie" {
entry:
  %object = call i8 addrspace(1)* @llvm.cj.alloca.generic(
      i8* bitcast (%TypeInfo* @RefPayload.ti to i8*), i32 8)
  %carrier = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.raw = getelementptr i8*, i8* addrspace(1)* %carrier, i32 1
  %payload = bitcast i8* addrspace(1)* %payload.raw to i8 addrspace(1)*
  %dst.object = alloca %OtherPayload, align 8
  %dst = bitcast %OtherPayload* %dst.object to i8*
  call void @llvm.cj.memset(i8* %dst, i8 0, i64 8, i1 false)
  call void @llvm.memcpy.p0i8.p1i8.i64(
      i8* %dst, i8 addrspace(1)* %payload, i64 8, i1 false)
  ret void
}

declare i8 addrspace(1)* @llvm.cj.alloca.generic(i8*, i32)
declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
!0 = !{!"RefPayload"}

;--- managed-interior.ll
%RefPayload = type { i8 addrspace(1)* }

define void @managed_interior() gc "cangjie" {
entry:
  %object = call i8 addrspace(1)* @managed()
  %carrier = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %interior.raw = getelementptr i8*, i8* addrspace(1)* %carrier, i32 2
  %typed = bitcast i8* addrspace(1)* %interior.raw to %RefPayload addrspace(1)*
  %src = bitcast %RefPayload addrspace(1)* %typed to i8 addrspace(1)*
  %dst.object = alloca %RefPayload, align 8
  %dst = bitcast %RefPayload* %dst.object to i8*
  call void @llvm.cj.memset(i8* %dst, i8 0, i64 8, i1 false)
  call void @llvm.memcpy.p0i8.p1i8.i64(
      i8* %dst, i8 addrspace(1)* %src, i64 8, i1 false)
  ret void
}

declare i8 addrspace(1)* @managed() gc "cangjie"
declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
