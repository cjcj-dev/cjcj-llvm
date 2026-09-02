; RUN: split-file %s %t
; RUN: opt -passes=cj-ir-verifier < %t/allow.ll -disable-output
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-no-noalias.ll -disable-output 2>&1 | FileCheck %s --check-prefixes=NOALIAS,ABORT
; RUN: not not opt -disable-verify -passes=cj-ir-verifier < %t/reject-byval.ll -disable-output 2>&1 | FileCheck %s --check-prefixes=BYVAL,ABORT
; A non-Cangjie-GC function remains outside CJIRVerifier's function scope.
; RUN: opt -passes=cj-ir-verifier < %t/outside-verifier-scope.ll -disable-output 2> %t/outside-verifier-scope.err
; RUN: count 0 < %t/outside-verifier-scope.err
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-wrapper.ll -disable-output 2>&1 | FileCheck %s --check-prefixes=WRAPPER,ABORT
; RUN: not opt -passes=cj-ir-verifier < %t/reject-nonstring-constant-global-source.ll -disable-output 2>&1 | FileCheck %s --check-prefixes=NONSTRING,ABORT
; RUN: opt -passes=cj-ir-verifier < %t/allow-canonical-cjstring-global-source.ll -disable-output
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-mutable-global-source.ll -disable-output 2>&1 | FileCheck %s --check-prefixes=MUTABLE,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-layout.ll -disable-output 2>&1 | FileCheck %s --check-prefixes=LAYOUT,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-size.ll -disable-output 2>&1 | FileCheck %s --check-prefixes=SIZE,ABORT

; NOALIAS: in function reject_sret_without_noalias
; BYVAL: in function reject_sret_with_byval
; WRAPPER: in function reject_sret_cfunc_wrapper
; NONSTRING: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; MUTABLE: in function reject_sret_from_mutable_global_source
; LAYOUT: in function reject_sret_layout_mismatch
; SIZE: in function reject_sret_partial_size
; ABORT: LLVM ERROR: Broken function found, compilation aborted
; ABORT: error: Aborted

;--- allow.ll
target datalayout = "e-p:64:64-p1:64:64"
%S = type { i8 addrspace(1)*, i64 }

define void @allow_sret_from_registered_source(%S* noalias sret(%S) %dst) gc "cangjie" {
entry:
  %src = alloca %S, align 8
  %dst.i8 = bitcast %S* %dst to i8*
  %src.i8 = bitcast %S* %src to i8*
  call void @llvm.cj.memset(i8* %src.i8, i8 0, i64 16, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}

define void @allow_sret_from_abi_source(%S* noalias sret(%S) %dst,
                                        %S* noalias %src) gc "cangjie" {
entry:
  %dst.i8 = bitcast %S* %dst to i8*
  %src.i8 = bitcast %S* %src to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-no-noalias.ll
target datalayout = "e-p:64:64-p1:64:64"
%S = type { i8 addrspace(1)*, i64 }
define void @reject_sret_without_noalias(%S* sret(%S) %dst) gc "cangjie" {
entry:
  %src = alloca %S
  %dst.i8 = bitcast %S* %dst to i8*
  %src.i8 = bitcast %S* %src to i8*
  call void @llvm.cj.memset(i8* %src.i8, i8 0, i64 16, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}
declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-byval.ll
target datalayout = "e-p:64:64-p1:64:64"
%S = type { i8 addrspace(1)*, i64 }
define void @reject_sret_with_byval(%S* noalias sret(%S) byval(%S) %dst) gc "cangjie" {
entry:
  %src = alloca %S
  %dst.i8 = bitcast %S* %dst to i8*
  %src.i8 = bitcast %S* %src to i8*
  call void @llvm.cj.memset(i8* %src.i8, i8 0, i64 16, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}
declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- outside-verifier-scope.ll
target datalayout = "e-p:64:64-p1:64:64"
%S = type { i8 addrspace(1)*, i64 }
define void @outside_cangjie_gc_sret_scope(%S* noalias sret(%S) %dst) {
entry:
  %src = alloca %S
  %dst.i8 = bitcast %S* %dst to i8*
  %src.i8 = bitcast %S* %src to i8*
  call void @llvm.cj.memset(i8* %src.i8, i8 0, i64 16, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}
declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-wrapper.ll
target datalayout = "e-p:64:64-p1:64:64"
%S = type { i8 addrspace(1)*, i64 }
define void @reject_sret_cfunc_wrapper(%S* noalias sret(%S) %dst) #0 gc "cangjie" {
entry:
  %src = alloca %S
  %dst.i8 = bitcast %S* %dst to i8*
  %src.i8 = bitcast %S* %src to i8*
  call void @llvm.cj.memset(i8* %src.i8, i8 0, i64 16, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}
declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
attributes #0 = { "cfunc" }

;--- reject-nonstring-constant-global-source.ll
target datalayout = "e-p:64:64-p1:64:64"
%S = type { i8 addrspace(1)*, i64 }
@source = internal constant %S { i8 addrspace(1)* null, i64 0 }
define void @reject_sret_from_nonstring_constant_global_source(%S* noalias sret(%S) %dst) gc "cangjie" {
entry:
  %dst.i8 = bitcast %S* %dst to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* bitcast (%S* @source to i8*), i64 16, i1 false)
  ret void
}
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- allow-canonical-cjstring-global-source.ll
target datalayout = "e-p:64:64-p1:64:64"
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #0
@literal = private constant %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #1

define void @allow_sret_from_canonical_cjstring_global_source(%"record.std.core:String"* noalias sret(%"record.std.core:String") %dst) gc "cangjie" {
entry:
  %dst.i8 = bitcast %"record.std.core:String"* %dst to i8*
  %src.i8 = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #0 = { "cjstring_data" }
attributes #1 = { "cjstring_literal" }

;--- reject-mutable-global-source.ll
target datalayout = "e-p:64:64-p1:64:64"
%S = type { i8 addrspace(1)*, i64 }
@source = internal global %S zeroinitializer
define void @reject_sret_from_mutable_global_source(%S* noalias sret(%S) %dst) gc "cangjie" {
entry:
  %dst.i8 = bitcast %S* %dst to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* bitcast (%S* @source to i8*), i64 16, i1 false)
  ret void
}
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-layout.ll
target datalayout = "e-p:64:64-p1:64:64"
%Dst = type { i8 addrspace(1)*, i64 }
%Src = type { i64, i8 addrspace(1)* }
define void @reject_sret_layout_mismatch(%Dst* noalias sret(%Dst) %dst) gc "cangjie" {
entry:
  %src = alloca %Src
  %dst.i8 = bitcast %Dst* %dst to i8*
  %src.i8 = bitcast %Src* %src to i8*
  call void @llvm.cj.memset(i8* %src.i8, i8 0, i64 16, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 16, i1 false)
  ret void
}
declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

;--- reject-size.ll
target datalayout = "e-p:64:64-p1:64:64"
%S = type { i8 addrspace(1)*, i64 }
define void @reject_sret_partial_size(%S* noalias sret(%S) %dst) gc "cangjie" {
entry:
  %src = alloca %S
  %dst.i8 = bitcast %S* %dst to i8*
  %src.i8 = bitcast %S* %src to i8*
  call void @llvm.cj.memset(i8* %src.i8, i8 0, i64 16, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 8, i1 false)
  ret void
}
declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
