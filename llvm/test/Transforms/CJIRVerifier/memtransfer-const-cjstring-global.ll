; RUN: split-file %s %t
; RUN: opt -passes=cj-ir-verifier < %t/allow.ll -disable-output
; RUN: not opt -passes=cj-ir-verifier < %t/reject-mutable.ll -disable-output 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not opt -passes=cj-ir-verifier < %t/reject-noattr.ll -disable-output 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not opt -passes=cj-ir-verifier < %t/reject-baddata.ll -disable-output 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not opt -passes=cj-ir-verifier < %t/reject-bounds.ll -disable-output 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not opt -passes=cj-ir-verifier < %t/reject-dynamic.ll -disable-output 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not opt -passes=cj-ir-verifier < %t/reject-partial.ll -disable-output 2>&1 | FileCheck %s --check-prefix=REJECT

; The source-only exemption is restricted to the compiler's immutable String
; literal/data pair.  The destination remains a Cangjie sret root.

;--- allow.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private constant %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @allow(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" }
attributes #2 = { "cjstring_literal" }

;--- reject-mutable.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }
@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2
define void @reject_mutable(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" }
attributes #2 = { "cjstring_literal" }

;--- reject-noattr.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }
@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private constant %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 }
define void @reject_noattr(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" }

;--- reject-baddata.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }
@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !1
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private constant %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2
define void @reject_bad_data(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!1 = !{!"ArrayLayout.NotUInt8"}
attributes #1 = { "cjstring_data" }
attributes #2 = { "cjstring_literal" }

;--- reject-bounds.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }
@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private constant %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 3, i32 2 } #2
define void @reject_bounds(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" }
attributes #2 = { "cjstring_literal" }

;--- reject-dynamic.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }
@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private constant %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2
declare i8* @get_source()
define void @reject_dynamic(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %slot = alloca i8*, align 8
  store i8* bitcast (%"record.std.core:String"* @literal to i8*), i8** %slot
  %loaded = load i8*, i8** %slot
  br i1 true, label %left, label %right
left:
  br label %merge
right:
  %called = call i8* @get_source()
  br label %merge
merge:
  %p = phi i8* [ %loaded, %left ], [ %called, %right ]
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %p, i64 16, i1 false)
  ret void
}
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" }
attributes #2 = { "cjstring_literal" }

;--- reject-partial.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }
@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private constant %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2
define void @reject_partial(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 8, i1 false)
  ret void
}
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" }
attributes #2 = { "cjstring_literal" }

; REJECT: Bare memcpy/memmove
