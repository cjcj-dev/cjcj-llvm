; RUN: split-file %s %t
; RUN: opt -passes=cj-ir-verifier < %t/allow-uncolour-ptrmask.ll -disable-output
; RUN: not opt -passes=cj-ir-verifier < %t/reject-bare-as1-arg.ll -disable-output 2>%t/reject-bare.err; echo BARE_RC=$? >> %t/reject-bare.err
; RUN: FileCheck %s -check-prefix=BARE < %t/reject-bare.err
; RUN: not opt -passes=cj-ir-verifier < %t/reject-lowbit-ptrmask.ll -disable-output 2>%t/reject-lowbit.err; echo LOWBIT_RC=$? >> %t/reject-lowbit.err
; RUN: FileCheck %s -check-prefix=LOWBIT < %t/reject-lowbit.err

; (a) official malloc.array payload memmove with llvm.ptrmask uncolour mask.
;--- allow-uncolour-ptrmask.ll
%ArrayBase = type { i64 }
%ArrayLayout.UInt8 = type { %ArrayBase, [0 x i8] }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }

@digits100 = internal constant [200 x i8] zeroinitializer
@RawArrayUInt8.ti = external global %TypeInfo, !RelatedType !0

define void @allow_uncolour_ptrmask_memmove() gc "cangjie" {
entry:
  %rawarray = call i8 addrspace(1)* @llvm.cj.malloc.array(
      i8* bitcast (%TypeInfo* @RawArrayUInt8.ti to i8*), i64 200, i64 1)
  %uncolor.ptr = call i8 addrspace(1)* @llvm.ptrmask.p1i8.i64(i8 addrspace(1)* %rawarray, i64 281474976710655)
  %array.cast = bitcast i8 addrspace(1)* %uncolor.ptr to i8* addrspace(1)*
  %object.payload = getelementptr i8*, i8* addrspace(1)* %array.cast, i32 1
  %layout = bitcast i8* addrspace(1)* %object.payload to %ArrayLayout.UInt8 addrspace(1)*
  %elements = getelementptr inbounds %ArrayLayout.UInt8, %ArrayLayout.UInt8 addrspace(1)* %layout, i32 0, i32 1
  %dst = bitcast [0 x i8] addrspace(1)* %elements to i8 addrspace(1)*
  call void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)* %dst,
      i8 addrspace(1)* addrspacecast (i8* getelementptr inbounds ([200 x i8], [200 x i8]* @digits100, i32 0, i32 0) to i8 addrspace(1)*), i64 200, i1 false)
  ret void
}

declare i8 addrspace(1)* @llvm.cj.malloc.array(i8*, i64, i64)
declare i8 addrspace(1)* @llvm.ptrmask.p1i8.i64(i8 addrspace(1)*, i64)
declare void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)*, i8 addrspace(1)*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}

; (b) bare AS1 argument destination remains unknown.
;--- reject-bare-as1-arg.ll
define void @reject_bare_as1_arg(i8 addrspace(1)* %dst, i8 addrspace(1)* %src) gc "cangjie" {
entry:
  call void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)* %dst, i8 addrspace(1)* %src, i64 8, i1 false)
  ret void
}

declare void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)*, i8 addrspace(1)*, i64, i1)

; BARE: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance.
; BARE: LLVM ERROR: Broken function found, compilation aborted

; (c) ptrmask that clears low 4 bits is not uncolour; stay unknown.
;--- reject-lowbit-ptrmask.ll
%ArrayBase = type { i64 }
%ArrayLayout.UInt8 = type { %ArrayBase, [0 x i8] }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }

@digits100 = internal constant [200 x i8] zeroinitializer
@RawArrayUInt8.ti = external global %TypeInfo, !RelatedType !0

define void @reject_lowbit_ptrmask_memmove() gc "cangjie" {
entry:
  %rawarray = call i8 addrspace(1)* @llvm.cj.malloc.array(
      i8* bitcast (%TypeInfo* @RawArrayUInt8.ti to i8*), i64 200, i64 1)
  %align.ptr = call i8 addrspace(1)* @llvm.ptrmask.p1i8.i64(i8 addrspace(1)* %rawarray, i64 -16)
  %array.cast = bitcast i8 addrspace(1)* %align.ptr to i8* addrspace(1)*
  %object.payload = getelementptr i8*, i8* addrspace(1)* %array.cast, i32 1
  %layout = bitcast i8* addrspace(1)* %object.payload to %ArrayLayout.UInt8 addrspace(1)*
  %elements = getelementptr inbounds %ArrayLayout.UInt8, %ArrayLayout.UInt8 addrspace(1)* %layout, i32 0, i32 1
  %dst = bitcast [0 x i8] addrspace(1)* %elements to i8 addrspace(1)*
  call void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)* %dst,
      i8 addrspace(1)* addrspacecast (i8* getelementptr inbounds ([200 x i8], [200 x i8]* @digits100, i32 0, i32 0) to i8 addrspace(1)*), i64 200, i1 false)
  ret void
}

declare i8 addrspace(1)* @llvm.cj.malloc.array(i8*, i64, i64)
declare i8 addrspace(1)* @llvm.ptrmask.p1i8.i64(i8 addrspace(1)*, i64)
declare void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)*, i8 addrspace(1)*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}

; LOWBIT: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance.
; LOWBIT: LLVM ERROR: Broken function found, compilation aborted
