; RUN: split-file %s %t
; RUN: opt -passes=cj-ir-verifier < %t/allow.ll -disable-output
; RUN: not --crash opt -passes=cj-ir-verifier < %t/reject-byval.ll -disable-output 2>&1 | FileCheck %s --check-prefixes=BYVAL,ABORT
; RUN: not --crash opt -passes=cj-ir-verifier < %t/reject-no-noalias.ll -disable-output 2>&1 | FileCheck %s --check-prefixes=NOALIAS,ABORT
; RUN: not --crash opt -passes=cj-ir-verifier < %t/reject-sret-source.ll -disable-output 2>&1 | FileCheck %s --check-prefixes=SRET,ABORT
; CJIRVerifier only visits gc "cangjie" functions.  Keep the non-GC case as a
; scope control; isABIForwardedAggregateArgument still rejects it if that outer
; scope is deliberately opened by the fault arm.
; RUN: opt -passes=cj-ir-verifier < %t/outside-cangjie-gc-scope.ll -disable-output 2> %t/outside.err
; RUN: count 0 < %t/outside.err

; BYVAL: in function reject_whole_argument_byval
; NOALIAS: in function reject_whole_argument_without_noalias
; SRET: in function reject_whole_sret_as_source
; ABORT: LLVM ERROR: Broken function found, compilation aborted
; ABORT: error: Aborted

;--- allow.ll
target datalayout = "e-p:64:64-p1:64:64"
%SrcPayload = type { i8 addrspace(1)*, i64 }
%DstPayload = type { i8 addrspace(1)*, i64 }

define void @allow_whole_argument_source(%SrcPayload* noalias %src) gc "cangjie" {
entry:
  %dst = alloca %DstPayload, align 8
  %dst.i8 = bitcast %DstPayload* %dst to i8*
  %src.i8 = bitcast %SrcPayload* %src to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-byval.ll
target datalayout = "e-p:64:64-p1:64:64"
%SrcPayload = type { i8 addrspace(1)*, i64 }
%DstPayload = type { i8 addrspace(1)*, i64 }

define void @reject_whole_argument_byval(%SrcPayload* noalias byval(%SrcPayload) %src) gc "cangjie" {
entry:
  %dst = alloca %DstPayload, align 8
  %dst.i8 = bitcast %DstPayload* %dst to i8*
  %src.i8 = bitcast %SrcPayload* %src to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-no-noalias.ll
target datalayout = "e-p:64:64-p1:64:64"
%SrcPayload = type { i8 addrspace(1)*, i64 }
%DstPayload = type { i8 addrspace(1)*, i64 }

define void @reject_whole_argument_without_noalias(%SrcPayload* %src) gc "cangjie" {
entry:
  %dst = alloca %DstPayload, align 8
  %dst.i8 = bitcast %DstPayload* %dst to i8*
  %src.i8 = bitcast %SrcPayload* %src to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-sret-source.ll
target datalayout = "e-p:64:64-p1:64:64"
%SrcPayload = type { i8 addrspace(1)*, i64 }
%DstPayload = type { i8 addrspace(1)*, i64 }

define void @reject_whole_sret_as_source(%SrcPayload* noalias sret(%SrcPayload) %src) gc "cangjie" {
entry:
  %dst = alloca %DstPayload, align 8
  %dst.i8 = bitcast %DstPayload* %dst to i8*
  %src.i8 = bitcast %SrcPayload* %src to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- outside-cangjie-gc-scope.ll
target datalayout = "e-p:64:64-p1:64:64"
%SrcPayload = type { i8 addrspace(1)*, i64 }
%DstPayload = type { i8 addrspace(1)*, i64 }

define void @outside_cangjie_gc_scope(%SrcPayload* noalias %src) {
entry:
  %dst = alloca %DstPayload, align 8
  %dst.i8 = bitcast %DstPayload* %dst to i8*
  %src.i8 = bitcast %SrcPayload* %src to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
