; RUN: split-file %s %t
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-helper-alias-write.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-cmpxchg.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: opt -passes=cj-ir-verifier -disable-output %t/allow-byval.ll
; RUN: opt -passes=cj-ir-verifier -disable-output %t/allow-helper-spill.ll
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-spill-store.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-spill-escape.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-spill-slot-escape.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: opt -passes=cj-ir-verifier -disable-output %t/allow-deferred.ll
; RUN: opt -passes=cj-ir-verifier -disable-output %t/allow-prefix.ll
; RUN: opt -passes=cj-ir-verifier -disable-output %t/allow-value-load.ll
; RUN: opt -passes=cj-ir-verifier -disable-output %t/allow-helper-attrs.ll
; RUN: opt -passes=cj-ir-verifier -disable-output %t/allow-helper-body.ll
; RUN: opt -passes=cj-ir-verifier -disable-output %t/allow-alias.ll
; RUN: opt -passes=cj-ir-verifier -disable-output %t/allow-loop.ll
; RUN: opt -passes=cj-ir-verifier -disable-output %t/allow-direct-nonzero.ll
; RUN: opt -passes=cj-ir-verifier -disable-output %t/allow-mixed-nonzero.ll
; RUN: opt -passes=cj-ir-verifier -disable-output %t/allow-legacy-nonzero.ll
; RUN: opt -passes=cj-ir-verifier -disable-output %t/allow-empty.ll
; RUN: opt -passes=cj-ir-verifier -disable-output %t/allow-nul.ll
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-nonzero.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-shared-nonzero.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-shared-bounds.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-cache.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-store.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-same-src-dst.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-atomic.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-loop-store.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-alias-store.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-global-address.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-aggregate-address.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-helper-return.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-readonly-capture.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-nocapture-write.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-ptrtoint.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-asm.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-unknown-call.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-data-undef.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-bad-header.ll 2>&1 | FileCheck %s --check-prefix=REJECT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/reject-relatedtype.ll 2>&1 | FileCheck %s --check-prefix=REJECT

; Each reject reaches the complete typed copy in @target, before any other
; Cangjie function is verified. Extra native users exercise the source graph.
; REJECT: Bare memcpy/memmove
; REJECT: call void @llvm.memcpy.p0i8.p0i8.i64
; REJECT: in function target

;--- allow-deferred.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }


;--- allow-prefix.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 2 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }


;--- allow-value-load.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }

define i8 addrspace(1)* @read_buffer() {
 %p = getelementptr %"record.std.core:String", %"record.std.core:String"* @literal, i32 0, i32 0
 %v = load i8 addrspace(1)*, i8 addrspace(1)** %p
 ret i8 addrspace(1)* %v
}

;--- allow-helper-attrs.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }

declare i32 @read(i8* nocapture readonly)
define i32 @use() {
 %p = bitcast %"record.std.core:String"* @literal to i8*
 %v = call i32 @read(i8* %p)
 ret i32 %v
}

;--- allow-helper-body.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }

define internal i32 @read(%"record.std.core:String"* %p) {
 %q = getelementptr %"record.std.core:String", %"record.std.core:String"* %p, i32 0, i32 2
 %v = load i32, i32* %q
 ret i32 %v
}
define i32 @use() {
 %v = call i32 @read(%"record.std.core:String"* @literal)
 ret i32 %v
}

;--- allow-alias.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }

@alias = internal alias %"record.std.core:String", %"record.std.core:String"* @literal
define i32 @read_alias() {
 %p = getelementptr %"record.std.core:String", %"record.std.core:String"* @alias, i32 0, i32 2
 %v = load i32, i32* %p
 ret i32 %v
}

;--- allow-loop.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }

define i32 @cycle(i1 %exit) {
entry:
 br label %loop
loop:
 %p = phi %"record.std.core:String"* [@literal, %entry], [%q, %loop]
 %q = select i1 %exit, %"record.std.core:String"* %p, %"record.std.core:String"* @literal
 %r = getelementptr %"record.std.core:String", %"record.std.core:String"* %q, i32 0, i32 2
 %v = load i32, i32* %r
 br i1 %exit, label %done, label %loop
done:
 ret i32 %v
}

;--- allow-direct-nonzero.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 1, i32 2 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }

define i8 @direct() {
 %p = getelementptr %StringData, %StringData* @data, i32 0, i32 2, i32 0
 %v = load i8, i8* %p
 ret i8 %v
}

;--- allow-mixed-nonzero.ll
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
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }


;--- allow-legacy-nonzero.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private constant %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 1, i32 2 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
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


;--- allow-empty.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [0 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 0, [0 x i8] zeroinitializer } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 0 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }


;--- allow-nul.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] zeroinitializer } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }


;--- reject-nonzero.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 1, i32 2 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }


;--- reject-shared-nonzero.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }

@other = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 1, i32 2 } #2

;--- reject-shared-bounds.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }

@other = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 5 } #2

;--- reject-cache.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" "CJGlobalValue" }


;--- reject-store.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }

define void @write() {
 %p = getelementptr %"record.std.core:String", %"record.std.core:String"* @literal, i32 0, i32 2
 store i32 2, i32* %p
 ret void
}

;--- reject-same-src-dst.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }

define void @overwrite() {
 %p = bitcast %"record.std.core:String"* @literal to i8*
 call void @llvm.memcpy.p0i8.p0i8.i64(i8* %p, i8* %p, i64 16, i1 false)
 ret void
}

;--- reject-atomic.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }

define void @write() {
 %p = getelementptr %"record.std.core:String", %"record.std.core:String"* @literal, i32 0, i32 2
 %old = atomicrmw add i32* %p, i32 1 monotonic
 ret void
}

;--- reject-loop-store.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }

define void @cycle(i1 %exit) {
entry:
 br label %loop
loop:
 %p = phi %"record.std.core:String"* [@literal, %entry], [%q, %loop]
 %q = select i1 %exit, %"record.std.core:String"* %p, %"record.std.core:String"* @literal
 %r = getelementptr %"record.std.core:String", %"record.std.core:String"* %q, i32 0, i32 2
 store i32 3, i32* %r
 br i1 %exit, label %done, label %loop
done:
 ret void
}

;--- reject-alias-store.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }

@alias = internal alias %"record.std.core:String", %"record.std.core:String"* @literal
define void @write() {
 %p = getelementptr %"record.std.core:String", %"record.std.core:String"* @alias, i32 0, i32 2
 store i32 2, i32* %p
 ret void
}

;--- reject-global-address.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }

@escape = global %"record.std.core:String"* @literal

;--- reject-aggregate-address.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }

@escape = global { %"record.std.core:String"* } { %"record.std.core:String"* @literal }

;--- reject-helper-return.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }

define internal %"record.std.core:String"* @retaddr(%"record.std.core:String"* %p) readonly {
 ret %"record.std.core:String"* %p
}
define %"record.std.core:String"* @escape() {
 %p = call %"record.std.core:String"* @retaddr(%"record.std.core:String"* @literal)
 ret %"record.std.core:String"* %p
}

;--- reject-readonly-capture.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }

declare i8* @capture(i8*) readonly
define i8* @escape() {
 %p = bitcast %"record.std.core:String"* @literal to i8*
 %v = call i8* @capture(i8* %p)
 ret i8* %v
}

;--- reject-nocapture-write.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }

declare void @write(i8* nocapture)
define void @use() {
 %p = bitcast %"record.std.core:String"* @literal to i8*
 call void @write(i8* %p)
 ret void
}

;--- reject-ptrtoint.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }

define i64 @escape() {
 %p = ptrtoint %"record.std.core:String"* @literal to i64
 ret i64 %p
}

;--- reject-asm.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }

define void @escape() {
 call void asm sideeffect "", "r"(%"record.std.core:String"* @literal)
 ret void
}

;--- reject-unknown-call.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }

declare void @unknown(%"record.std.core:String"*)
define void @use() {
 call void @unknown(%"record.std.core:String"* @literal)
 ret void
}

;--- reject-data-undef.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] undef } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }


;--- reject-bad-header.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 3, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }


;--- reject-relatedtype.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.Int8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }



;--- allow-helper-spill.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }


define internal i32 @read(%"record.std.core:String"* %p) {
 %slot = alloca %"record.std.core:String"*
 store %"record.std.core:String"* %p, %"record.std.core:String"** %slot
 %q = load %"record.std.core:String"*, %"record.std.core:String"** %slot
 %field = getelementptr %"record.std.core:String", %"record.std.core:String"* %q, i32 0, i32 2
 %v = load i32, i32* %field
 ret i32 %v
}
define i32 @use() {
 %v = call i32 @read(%"record.std.core:String"* @literal)
 ret i32 %v
}

;--- reject-spill-store.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }


define void @write() {
 %slot = alloca %"record.std.core:String"*
 store %"record.std.core:String"* @literal, %"record.std.core:String"** %slot
 %q = load %"record.std.core:String"*, %"record.std.core:String"** %slot
 %field = getelementptr %"record.std.core:String", %"record.std.core:String"* %q, i32 0, i32 2
 store i32 2, i32* %field
 ret void
}

;--- reject-spill-escape.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }


@escape = global %"record.std.core:String"* null
define void @write() {
 %slot = alloca %"record.std.core:String"*
 store %"record.std.core:String"* @literal, %"record.std.core:String"** %slot
 %q = load %"record.std.core:String"*, %"record.std.core:String"** %slot
 store %"record.std.core:String"* %q, %"record.std.core:String"** @escape
 ret void
}

;--- reject-spill-slot-escape.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }


declare void @capture(%"record.std.core:String"** nocapture readonly)
define void @escape() {
 %slot = alloca %"record.std.core:String"*
 store %"record.std.core:String"* @literal, %"record.std.core:String"** %slot
 call void @capture(%"record.std.core:String"** %slot)
 ret void
}

;--- allow-byval.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }


declare void @by_value(%"record.std.core:String"* byval(%"record.std.core:String"))
define void @value_copy() {
 call void @by_value(%"record.std.core:String"* byval(%"record.std.core:String") @literal)
 ret void
}

;--- reject-helper-alias-write.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }


define internal void @helper(i8* nocapture readonly %read, i8* nocapture %write) {
 %v = load i8, i8* %read
 store i8 %v, i8* %write
 ret void
}
define void @use() {
 %p = bitcast %"record.std.core:String"* @literal to i8*
 %q = getelementptr i8, i8* %p, i64 0
 call void @helper(i8* %p, i8* %q)
 ret void
}

;--- reject-cmpxchg.ll
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%StringData = type { i8*, i64, [4 x i8] }

@"RawArray<UInt8>.ti" = external global %TypeInfo, !RelatedType !0
@data = private constant %StringData { i8* bitcast (%TypeInfo* @"RawArray<UInt8>.ti" to i8*), i64 4, [4 x i8] c"abcd" } #1
@literal = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast (%StringData* @data to i8*) to i8 addrspace(1)*), i32 0, i32 4 } #2

define void @target(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) gc "cangjie" {
entry:
  %dst = bitcast %"record.std.core:String"* %out to i8*
  %src = bitcast %"record.std.core:String"* @literal to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
!0 = !{!"ArrayLayout.UInt8"}
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }


define void @write() {
 %p = getelementptr %"record.std.core:String", %"record.std.core:String"* @literal, i32 0, i32 2
 %v = cmpxchg i32* %p, i32 4, i32 1 monotonic monotonic
 ret void
}
