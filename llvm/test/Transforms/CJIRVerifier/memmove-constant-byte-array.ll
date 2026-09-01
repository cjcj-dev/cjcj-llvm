; RUN: split-file %s %t
; RUN: opt -passes=cj-ir-verifier < %t/allow-constant-byte-array.ll -disable-output
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-reference-payload.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=REF,ABORT

; The source byte global and the destination malloc.array TypeInfo each prove
; independently that the complete copied payload has no managed references.
@digits100 = internal constant [200 x i8] zeroinitializer

;--- allow-constant-byte-array.ll
%ArrayBase = type { i64 }
%ArrayLayout.UInt8 = type { %ArrayBase, [0 x i8] }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }

@digits100 = internal constant [200 x i8] zeroinitializer
@RawArrayUInt8.ti = external global %TypeInfo, !RelatedType !0

define void @allow_constant_byte_array_memmove() gc "cangjie" {
entry:
  %array = call i8 addrspace(1)* @llvm.cj.malloc.array(
      i8* bitcast (%TypeInfo* @RawArrayUInt8.ti to i8*), i64 200, i64 1)
  %array.cast = bitcast i8 addrspace(1)* %array to i8* addrspace(1)*
  %object.payload = getelementptr i8*, i8* addrspace(1)* %array.cast, i32 1
  %layout = bitcast i8* addrspace(1)* %object.payload to %ArrayLayout.UInt8 addrspace(1)*
  %elements = getelementptr inbounds %ArrayLayout.UInt8, %ArrayLayout.UInt8 addrspace(1)* %layout, i32 0, i32 1
  %dst = bitcast [0 x i8] addrspace(1)* %elements to i8 addrspace(1)*
  call void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)* %dst,
      i8 addrspace(1)* addrspacecast (i8* getelementptr inbounds ([200 x i8], [200 x i8]* @digits100, i32 0, i32 0) to i8 addrspace(1)*), i64 200, i1 false)
  ret void
}

declare i8 addrspace(1)* @llvm.cj.malloc.array(i8*, i64, i64)
declare void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)*, i8 addrspace(1)*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}

;--- reject-reference-payload.ll
%ref_payload = type { i8 addrspace(1)* }

; REF: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; REF-NEXT: call void @llvm.memmove.p1i8.p0i8.i64
; REF: in function reject_reference_payload_memmove
define void @reject_reference_payload_memmove(i8 addrspace(1)* %dst) gc "cangjie" {
entry:
  %src = alloca %ref_payload, align 8
  %src.i8 = bitcast %ref_payload* %src to i8*
  call void @llvm.cj.memset(i8* %src.i8, i8 0, i64 8, i1 false)
  call void @llvm.memmove.p1i8.p0i8.i64(i8 addrspace(1)* %dst, i8* %src.i8, i64 8, i1 false)
  ret void
}

declare void @llvm.memmove.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)
declare void @llvm.cj.memset(i8*, i8, i64, i1)

; ABORT: LLVM ERROR: Broken function found, compilation aborted
; ABORT: error: Aborted
