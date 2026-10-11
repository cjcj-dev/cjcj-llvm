; RUN: split-file %s %t
; RUN: llvm-link %t/producer.ll %t/consumer.ll -o %t/input.bc
; RUN: opt -passes='default<O0>' -cangjie-pipeline %t/input.bc -o %t/o0.bc
; RUN: opt -passes=globaldce %t/o0.bc -o %t/o0.native.bc
; RUN: lli %t/o0.native.bc | FileCheck %s --check-prefix=MERGED
; RUN: opt -passes='default<O1>' -cangjie-pipeline %t/input.bc -o %t/o1.bc
; RUN: opt -passes=globaldce %t/o1.bc -o %t/o1.native.bc
; RUN: lli %t/o1.native.bc | FileCheck %s --check-prefix=MERGED
; RUN: opt -passes='default<O2>' -cangjie-pipeline %t/input.bc -o %t/o2.bc
; RUN: opt -passes=globaldce %t/o2.bc -o %t/o2.native.bc
; RUN: lli %t/o2.native.bc | FileCheck %s --check-prefix=MERGED
; RUN: opt -passes='default<O1>' -cangjie-pipeline -cj-string-pool-merge=false %t/input.bc -o %t/off.bc
; RUN: opt -passes=globaldce %t/off.bc -o %t/off.native.bc
; RUN: lli %t/off.native.bc | FileCheck %s --check-prefix=UNMERGED
; RUN: opt -passes='default<O1>' -cangjie-pipeline -cangjie-lto %t/producer.ll -o %t/producer.pre.bc
; RUN: opt -passes='default<O1>' -cangjie-pipeline -cangjie-lto %t/consumer.ll -o %t/consumer.pre.bc
; RUN: llvm-link %t/producer.pre.bc %t/consumer.pre.bc -o %t/linked.pre.bc
; RUN: opt -passes='lto<O1>' -cangjie-pipeline %t/linked.pre.bc -o %t/full.bc
; RUN: opt -passes=globaldce %t/full.bc -o %t/full.native.bc
; RUN: lli %t/full.native.bc | FileCheck %s --check-prefix=MERGED
;
; These native value consumers exercise the real Cangjie pipelines, pool and
; prelink GlobalOpt barrier. GC-qualified admission is tested separately in
; CJIRVerifier/memtransfer-deferred-cjstring-global.ll. After each pipeline,
; ordinary GlobalDCE removes unused runtime stub globals so lli can consume a
; closed native program; no runtime callback or stub implementation is added.
; Observe contained substring cde, suffix/prefix overlap efg, legacy slice rst,
; the actual final starts, prefix lengths, and a non-layout length control.
; MERGED: values=cde/efg/rst starts=2,4,2 lens=3,3,3 control=6
; UNMERGED: values=cde/efg/rst starts=0,0,2 lens=3,3,3 control=6
;
;--- producer.ll
target triple = "x86_64-unknown-linux-gnu"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
@ti = private global %TypeInfo zeroinitializer, !RelatedType !0
@data_long = private constant { i8*, i64, [6 x i8] } { i8* bitcast (%TypeInfo* @ti to i8*), i64 6, [6 x i8] c"abcdef" } #1
@long = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast ({ i8*, i64, [6 x i8] }* @data_long to i8*) to i8 addrspace(1)*), i32 0, i32 6 } #2
@data_cde = private constant { i8*, i64, [4 x i8] } { i8* bitcast (%TypeInfo* @ti to i8*), i64 4, [4 x i8] c"cdef" } #1
@cde = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast ({ i8*, i64, [4 x i8] }* @data_cde to i8*) to i8 addrspace(1)*), i32 0, i32 3 } #2
define void @copy_cde(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) noinline {
 %dst = bitcast %"record.std.core:String"* %out to i8*
 call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* bitcast (%"record.std.core:String"* @cde to i8*), i64 16, i1 false)
 ret void
}
@data_efg = private constant { i8*, i64, [4 x i8] } { i8* bitcast (%TypeInfo* @ti to i8*), i64 4, [4 x i8] c"efgh" } #1
@efg = private global %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast ({ i8*, i64, [4 x i8] }* @data_efg to i8*) to i8 addrspace(1)*), i32 0, i32 3 } #2
define void @copy_efg(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) noinline {
 %dst = bitcast %"record.std.core:String"* %out to i8*
 call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* bitcast (%"record.std.core:String"* @efg to i8*), i64 16, i1 false)
 ret void
}
@data_rst = private constant { i8*, i64, [6 x i8] } { i8* bitcast (%TypeInfo* @ti to i8*), i64 6, [6 x i8] c"pqrstu" } #3
@rst = private constant %"record.std.core:String" { i8 addrspace(1)* addrspacecast (i8* bitcast ({ i8*, i64, [6 x i8] }* @data_rst to i8*) to i8 addrspace(1)*), i32 2, i32 3 } #2
define void @copy_rst(%"record.std.core:String"* noalias sret(%"record.std.core:String") %out) noinline {
 %dst = bitcast %"record.std.core:String"* %out to i8*
 call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* bitcast (%"record.std.core:String"* @rst to i8*), i64 16, i1 false)
 ret void
}
define i32 @retain_long() {
 %v = load i32, i32* getelementptr (%"record.std.core:String", %"record.std.core:String"* @long, i32 0, i32 2)
 ret i32 %v
}
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
attributes #1 = { "cjstring_data" "cjstring_deferred" }
attributes #2 = { "cjstring_literal" }
attributes #3 = { "cjstring_data" }
!0 = !{!"ArrayLayout.UInt8"}

!llvm.module.flags = !{!20}
!20 = !{i32 1, !"CJBC", i32 1}

;--- consumer.ll
target triple = "x86_64-unknown-linux-gnu"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
@format = private constant [70 x i8] c"values=%c%c%c/%c%c%c/%c%c%c starts=%d,%d,%d lens=%d,%d,%d control=%d\0A\00"
declare void @copy_cde(%"record.std.core:String"* sret(%"record.std.core:String"))
declare void @copy_efg(%"record.std.core:String"* sret(%"record.std.core:String"))
declare void @copy_rst(%"record.std.core:String"* sret(%"record.std.core:String"))
declare i32 @retain_long()
declare i32 @printf(i8*, ...)
define i32 @main() {
 %cde = alloca %"record.std.core:String", align 8
 call void @copy_cde(%"record.std.core:String"* sret(%"record.std.core:String") %cde)
 %cde.bp = getelementptr %"record.std.core:String", %"record.std.core:String"* %cde, i32 0, i32 0
 %cde.b = load i8 addrspace(1)*, i8 addrspace(1)** %cde.bp
 %cde.native = addrspacecast i8 addrspace(1)* %cde.b to i8*
 %cde.sp = getelementptr %"record.std.core:String", %"record.std.core:String"* %cde, i32 0, i32 1
 %cde.start = load i32, i32* %cde.sp
 %cde.lp = getelementptr %"record.std.core:String", %"record.std.core:String"* %cde, i32 0, i32 2
 %cde.len = load i32, i32* %cde.lp
 %cde.off0 = add i32 %cde.start, 16
 %cde.ptr0 = getelementptr i8, i8* %cde.native, i32 %cde.off0
 %cde.c0 = load i8, i8* %cde.ptr0
 %cde.v0 = zext i8 %cde.c0 to i32
 %cde.off1 = add i32 %cde.start, 17
 %cde.ptr1 = getelementptr i8, i8* %cde.native, i32 %cde.off1
 %cde.c1 = load i8, i8* %cde.ptr1
 %cde.v1 = zext i8 %cde.c1 to i32
 %cde.off2 = add i32 %cde.start, 18
 %cde.ptr2 = getelementptr i8, i8* %cde.native, i32 %cde.off2
 %cde.c2 = load i8, i8* %cde.ptr2
 %cde.v2 = zext i8 %cde.c2 to i32
 %efg = alloca %"record.std.core:String", align 8
 call void @copy_efg(%"record.std.core:String"* sret(%"record.std.core:String") %efg)
 %efg.bp = getelementptr %"record.std.core:String", %"record.std.core:String"* %efg, i32 0, i32 0
 %efg.b = load i8 addrspace(1)*, i8 addrspace(1)** %efg.bp
 %efg.native = addrspacecast i8 addrspace(1)* %efg.b to i8*
 %efg.sp = getelementptr %"record.std.core:String", %"record.std.core:String"* %efg, i32 0, i32 1
 %efg.start = load i32, i32* %efg.sp
 %efg.lp = getelementptr %"record.std.core:String", %"record.std.core:String"* %efg, i32 0, i32 2
 %efg.len = load i32, i32* %efg.lp
 %efg.off0 = add i32 %efg.start, 16
 %efg.ptr0 = getelementptr i8, i8* %efg.native, i32 %efg.off0
 %efg.c0 = load i8, i8* %efg.ptr0
 %efg.v0 = zext i8 %efg.c0 to i32
 %efg.off1 = add i32 %efg.start, 17
 %efg.ptr1 = getelementptr i8, i8* %efg.native, i32 %efg.off1
 %efg.c1 = load i8, i8* %efg.ptr1
 %efg.v1 = zext i8 %efg.c1 to i32
 %efg.off2 = add i32 %efg.start, 18
 %efg.ptr2 = getelementptr i8, i8* %efg.native, i32 %efg.off2
 %efg.c2 = load i8, i8* %efg.ptr2
 %efg.v2 = zext i8 %efg.c2 to i32
 %rst = alloca %"record.std.core:String", align 8
 call void @copy_rst(%"record.std.core:String"* sret(%"record.std.core:String") %rst)
 %rst.bp = getelementptr %"record.std.core:String", %"record.std.core:String"* %rst, i32 0, i32 0
 %rst.b = load i8 addrspace(1)*, i8 addrspace(1)** %rst.bp
 %rst.native = addrspacecast i8 addrspace(1)* %rst.b to i8*
 %rst.sp = getelementptr %"record.std.core:String", %"record.std.core:String"* %rst, i32 0, i32 1
 %rst.start = load i32, i32* %rst.sp
 %rst.lp = getelementptr %"record.std.core:String", %"record.std.core:String"* %rst, i32 0, i32 2
 %rst.len = load i32, i32* %rst.lp
 %rst.off0 = add i32 %rst.start, 16
 %rst.ptr0 = getelementptr i8, i8* %rst.native, i32 %rst.off0
 %rst.c0 = load i8, i8* %rst.ptr0
 %rst.v0 = zext i8 %rst.c0 to i32
 %rst.off1 = add i32 %rst.start, 17
 %rst.ptr1 = getelementptr i8, i8* %rst.native, i32 %rst.off1
 %rst.c1 = load i8, i8* %rst.ptr1
 %rst.v1 = zext i8 %rst.c1 to i32
 %rst.off2 = add i32 %rst.start, 18
 %rst.ptr2 = getelementptr i8, i8* %rst.native, i32 %rst.off2
 %rst.c2 = load i8, i8* %rst.ptr2
 %rst.v2 = zext i8 %rst.c2 to i32
 %control = call i32 @retain_long()
 %printed = call i32 (i8*, ...) @printf(i8* getelementptr ([70 x i8], [70 x i8]* @format, i32 0, i32 0), i32 %cde.v0, i32 %cde.v1, i32 %cde.v2, i32 %efg.v0, i32 %efg.v1, i32 %efg.v2, i32 %rst.v0, i32 %rst.v1, i32 %rst.v2, i32 %cde.start, i32 %efg.start, i32 %rst.start, i32 %cde.len, i32 %efg.len, i32 %rst.len, i32 %control)
 ret i32 0
}

!llvm.module.flags = !{!20}
!20 = !{i32 1, !"CJBC", i32 1}
