; RUN: split-file %s %t
; RUN: opt -passes=cj-ir-verifier -disable-output %t/safe-nonzero.ll
; RUN: opt -passes=cj-ir-verifier -disable-output %t/safe-empty.ll
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-nonzero-start-observed.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-nonzero-buffer-observed.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-shared-direct.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-shared-alias.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: opt -passes=cj-ir-verifier -disable-output %t/safe-shared.ll
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-mixed-dead-first.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-mixed-reversed.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-unresolved-view.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-byte-mismatch.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: opt -passes='default<O0>' -cangjie-pipeline -S %t/safe-nonzero.ll | FileCheck %s --check-prefix=NONZERO
; RUN: opt -passes='default<O1>' -cangjie-pipeline -cangjie-lto %t/safe-nonzero.ll -o %t/safe-nonzero.pre.bc
; RUN: opt -passes='lto<O1>' -cangjie-pipeline -S %t/safe-nonzero.pre.bc | FileCheck %s --check-prefix=NONZERO
; RUN: opt -passes='default<O0>' -cangjie-pipeline -S %t/safe-empty.ll | FileCheck %s --check-prefix=EMPTY
; RUN: opt -passes='default<O1>' -cangjie-pipeline -cangjie-lto %t/safe-empty.ll -o %t/safe-empty.pre.bc
; RUN: opt -passes='lto<O1>' -cangjie-pipeline -S %t/safe-empty.pre.bc | FileCheck %s --check-prefix=EMPTY
; NONZERO: @literal = private constant {{.*}}, i32 0, i32 3 }
; EMPTY: @literal = private constant {{.*}}, i32 0, i32 0 }
; REJECT: Bare memcpy/memmove
; REJECT: call void @llvm.memcpy.p0i8.p0i8.i64
; REJECT: in function target
;
; Nonzero bytes alone do not prove safety: actual observers must be checked.

;--- safe-nonzero.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [5 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 5, [5 x i8] c"ababa" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 2, i32 3 } #2

define internal void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) noinline optnone gc "cangjie" {
entry:
 %dst = bitcast %"record.std.core:String"* %out to i8*
 %src = bitcast %"record.std.core:String"* @literal to i8*
 call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
 ret void
}
define i32 @observe() noinline optnone {
 %out = alloca %"record.std.core:String", align 8
 %dst = bitcast %"record.std.core:String"* %out to i8*
 call void @llvm.cj.memset(i8* %dst, i8 0, i64 16, i1 false)
 call void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out)
 %len = call i32 @length(%"record.std.core:String"* %out)
 ret i32 %len
}
define internal i32 @length(%"record.std.core:String"* %p) noinline optnone {
 %lp = getelementptr %"record.std.core:String", %"record.std.core:String"* %p, i32 0, i32 2
 %len = load i32, i32* %lp
 ret i32 %len
}
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
declare void @llvm.cj.memset(i8*, i8, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }




;--- safe-empty.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [5 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 5, [5 x i8] c"ababa" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 5, i32 0 } #2

define internal void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) noinline optnone gc "cangjie" {
entry:
 %dst = bitcast %"record.std.core:String"* %out to i8*
 %src = bitcast %"record.std.core:String"* @literal to i8*
 call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
 ret void
}
define i32 @observe() noinline optnone {
 %out = alloca %"record.std.core:String", align 8
 %dst = bitcast %"record.std.core:String"* %out to i8*
 call void @llvm.cj.memset(i8* %dst, i8 0, i64 16, i1 false)
 call void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out)
 %len = call i32 @length(%"record.std.core:String"* %out)
 ret i32 %len
}
define internal i32 @length(%"record.std.core:String"* %p) noinline optnone {
 %lp = getelementptr %"record.std.core:String", %"record.std.core:String"* %p, i32 0, i32 2
 %len = load i32, i32* %lp
 ret i32 %len
}
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
declare void @llvm.cj.memset(i8*, i8, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }




;--- reject-nonzero-start-observed.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [5 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 5, [5 x i8] c"ababa" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 2, i32 3 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
 %dst = bitcast %"record.std.core:String"* %out to i8*
 %src = bitcast %"record.std.core:String"* @literal to i8*
 call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
 ret void
}
define i32 @raw_start() {
 %p = getelementptr %"record.std.core:String", %"record.std.core:String"* @literal, i32 0, i32 1
 %v = load i32, i32* %p
 ret i32 %v
}
define internal i32 @length(%"record.std.core:String"* %p) noinline optnone {
 %lp = getelementptr %"record.std.core:String", %"record.std.core:String"* %p, i32 0, i32 1
 %len = load i32, i32* %lp
 ret i32 %len
}
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
declare void @llvm.cj.memset(i8*, i8, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }




;--- reject-nonzero-buffer-observed.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [5 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 5, [5 x i8] c"ababa" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 2, i32 3 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
 %dst = bitcast %"record.std.core:String"* %out to i8*
 %src = bitcast %"record.std.core:String"* @literal to i8*
 call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
 ret void
}
define i8 addrspace(1)* @raw_buffer() {
 %p = getelementptr %"record.std.core:String", %"record.std.core:String"* @literal, i32 0, i32 0
 %v = load i8 addrspace(1)*, i8 addrspace(1)** %p
 ret i8 addrspace(1)* %v
}
define internal i32 @length(%"record.std.core:String"* %p) noinline optnone {
 %lp = getelementptr %"record.std.core:String", %"record.std.core:String"* %p, i32 0, i32 2
 %len = load i32, i32* %lp
 ret i32 %len
}
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
declare void @llvm.cj.memset(i8*, i8, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }




;--- reject-shared-direct.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

@other = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 1, i32 2 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  call void @llvm.cj.memset(i8* %dst, i8 0, i64 16, i1 false)
 %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
declare void @llvm.cj.memset(i8*, i8, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }


define i8 @direct() {
 %p = getelementptr %StringData, %StringData* @data, i32 0, i32 2, i32 0
 %v = load i8, i8* %p
 ret i8 %v
}



;--- reject-shared-alias.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

@other = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 1, i32 2 } #2
@alias = internal alias %StringData, %StringData* @data

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  call void @llvm.cj.memset(i8* %dst, i8 0, i64 16, i1 false)
 %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
declare void @llvm.cj.memset(i8*, i8, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }


define i8 @direct() {
 %p = getelementptr %StringData, %StringData* @alias, i32 0, i32 2, i32 0
 %v = load i8, i8* %p
 ret i8 %v
}


;--- safe-shared.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [5 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 5, [5 x i8] c"ababa" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 2, i32 3 } #2

@other = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 2, i32 3 } #2

define internal void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) noinline optnone gc "cangjie" {
entry:
 %dst = bitcast %"record.std.core:String"* %out to i8*
 %src = bitcast %"record.std.core:String"* @literal to i8*
 call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
 ret void
}
define i32 @observe() noinline optnone {
 %out = alloca %"record.std.core:String", align 8
 %dst = bitcast %"record.std.core:String"* %out to i8*
 call void @llvm.cj.memset(i8* %dst, i8 0, i64 16, i1 false)
 call void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out)
 %len = call i32 @length(%"record.std.core:String"* %out)
 ret i32 %len
}
define internal i32 @length(%"record.std.core:String"* %p) noinline optnone {
 %lp = getelementptr %"record.std.core:String", %"record.std.core:String"* %p, i32 0, i32 2
 %len = load i32, i32* %lp
 ret i32 %len
}
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
declare void @llvm.cj.memset(i8*, i8, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }




;--- reject-mixed-dead-first.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@first = private constant %StringData { i8* null, i64 4, [4 x i8] c"xxxx" } #1
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 1, i32 2 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  call void @llvm.cj.memset(i8* %dst, i8 0, i64 16, i1 false)
 %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
declare void @llvm.cj.memset(i8*, i8, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }




;--- reject-mixed-reversed.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 1, i32 2 } #2

@first = private constant %StringData { i8* null, i64 4, [4 x i8] c"xxxx" } #1

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  call void @llvm.cj.memset(i8* %dst, i8 0, i64 16, i1 false)
 %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
declare void @llvm.cj.memset(i8*, i8, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }




;--- reject-unresolved-view.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

@unresolved = private global { i8* } { i8* bitcast (%StringData* @data to i8*) }

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  call void @llvm.cj.memset(i8* %dst, i8 0, i64 16, i1 false)
 %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
declare void @llvm.cj.memset(i8*, i8, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }




;--- reject-byte-mismatch.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [5 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 5, [5 x i8] c"abcde" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 2, i32 3 } #2

define internal void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) noinline optnone gc "cangjie" {
entry:
 %dst = bitcast %"record.std.core:String"* %out to i8*
 %src = bitcast %"record.std.core:String"* @literal to i8*
 call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
 ret void
}
define i32 @observe() noinline optnone {
 %out = alloca %"record.std.core:String", align 8
 %dst = bitcast %"record.std.core:String"* %out to i8*
 call void @llvm.cj.memset(i8* %dst, i8 0, i64 16, i1 false)
 call void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out)
 %len = call i32 @length(%"record.std.core:String"* %out)
 ret i32 %len
}
define internal i32 @length(%"record.std.core:String"* %p) noinline optnone {
 %lp = getelementptr %"record.std.core:String", %"record.std.core:String"* %p, i32 0, i32 2
 %len = load i32, i32* %lp
 ret i32 %len
}
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
declare void @llvm.cj.memset(i8*, i8, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }




