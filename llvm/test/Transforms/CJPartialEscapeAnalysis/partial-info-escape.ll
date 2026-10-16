;RUN: opt '-passes=cj-pea' -S < %s | FileCheck %s

; ModuleID = '/home/dingshenke/DTS/64KBArray/BenchmarkLoop.bc'
source_filename = "default"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

%BitMap = type { i32, [0 x i8] }
%TypeTemplate = type { i8*, i8, i8, i16, i16, i8*, i8*, i8*, i8* }
%default.pkgInfoType = type { i32, i32, i32, i32, i8*, i8*, i8*, i8*, i8*, i8*, i8*, i8*, i8*, i8*, i8*, i8*, i8*, i8*, i8*, i8*, i8*, i8*, i8*, i8*, i8*, i8*, i8*, i8*, i8*, i8*, i8* }
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i32*, i8*, i8*, i8*, %TypeInfo*, i8*, i8* }
%ArrayLayout.refArray = type { %ArrayBase, [0 x i8 addrspace(1)*] }
%ArrayBase = type { i64 }
%ObjLayout._ZN7default3ObjE = type {i64, i64}
@A1_C_ZN7default3ObjEE.typeName = weak_odr global [22 x i8] c"A1_C_ZN7default3ObjEE\00", align 1
@_ZN7default3ObjE.ti = internal global %TypeInfo {i8* getelementptr inbounds ([12 x i8], [12 x i8]* @"default$Obj.name", i32 0, i32 0), i8 -128, i8 0, i16 2, i32 16, %BitMap* null, i32 0, i8 8, i8 0, i32* getelementptr inbounds ([1 x i32], [1 x i32]* @"default$Obj.ti.offsets", i32 0, i32 0), i8* null, i8* null, i8* bitcast ([1 x %TypeInfo*]* @"default$Obj.ti.fields" to i8*), %TypeInfo* @"std.core$Object.ti", i8* null, i8* bitcast ([1 x i8*]* @"default$Obj.fieldNames" to i8*) }, !RelatedType !1
@"default$Obj.name" = internal global [12 x i8] c"default$Obj\00", align 1
@"default$Obj.ti.offsets" = internal global [1 x i32] [i32 0]
@"default$Obj.ti.fields" = internal global [1 x %TypeInfo*] [%TypeInfo* @"std.core$Object.ti"]
@"default$Obj.fieldNames" = internal global [1 x i8*] [i8* getelementptr inbounds ([3 x i8], [3 x i8]* @"default$Obj.field.1.name", i32 0, i32 0)]
@"default$Obj.field.1.name" = internal global [3 x i8] c"aa\00", align 1
@"RawArray<Obj>.ti" = internal global %TypeInfo { i8* getelementptr inbounds ([14 x i8], [14 x i8]* @"RawArray<Obj>.name", i32 0, i32 0), i8 -126, i8 0, i16 0, i32 8, %BitMap* null, i32 0, i8 8, i8 0, i32* null, i8* bitcast (%TypeTemplate* @RawArray.tt to i8*), i8* null, i8* null, %TypeInfo* @"std.core$Object.ti", i8* null, i8* null }, !RelatedType !0
@"RawArray<Obj>.name" = internal global [14 x i8] c"RawArray<Obj>\00"
@RawArray.tt = external global %TypeTemplate
@"std.core$Object.ti" = external global %TypeInfo

define private i32 @"__cj_personality_v0$"(...) {
entry:
  ret i32 0
}

define fastcc void @_ZN7default15benchmarkLoopD4Ev() unnamed_addr #8 gc "cangjie" personality i32 (...)* @"__cj_personality_v0$" {
; CHECK-LABEL: @_ZN7default15benchmarkLoopD4Ev
; CHECK-LABEL: entry
; CHECK-NEXT: %0 = alloca { %TypeInfo*, %ObjLayout._ZN7default3ObjE }, align 8
; CHECK-NEXT: %1 = bitcast { %TypeInfo*, %ObjLayout._ZN7default3ObjE }* %0 to i8**

entry:
  %0 = call noalias i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @_ZN7default3ObjE.ti to i8*), i32 16)
  %1 = getelementptr inbounds i8, i8 addrspace(1)* %0, i64 8
  %2 = bitcast i8 addrspace(1)* %1 to i64 addrspace(1)*
  store i64 10, i64 addrspace(1)* %2, align 8
  store i64 100, i64 addrspace(1)* %2, align 8
  %3 = call noalias i8 addrspace(1)* @CJ_MCC_NewArray(i8* bitcast (%TypeInfo* @"RawArray<Obj>.ti" to i8*), i64 65536)
  %val.is-null = icmp eq i8 addrspace(1)* %0, null
  br i1 %val.is-null, label %arr.init.opt, label %arr.init.body

arr.init.body:                                    ; preds = %entry, %arr.init.body
  %iterator.0 = phi i64 [ %7, %arr.init.body ], [ 0, %entry ]
  %4 = getelementptr inbounds i8, i8 addrspace(1)* %3, i64 16
  %5 = bitcast i8 addrspace(1)* %4 to i8 addrspace(1)* addrspace(1)*
  %6 = getelementptr inbounds i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %5, i64 %iterator.0
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* nonnull %0, i8 addrspace(1)* %3, i8 addrspace(1)* addrspace(1)* %6)
  %7 = add i64 %iterator.0, 1
  %iterator.size.cmp = icmp slt i64 %7, 65536
  br i1 %iterator.size.cmp, label %arr.init.body, label %arr.init.opt

arr.init.opt:                                     ; preds = %arr.init.body, %entry
  ret void
}


; Function Attrs: argmemonly nounwind
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)* nocapture, i8 addrspace(1)* addrspace(1)* nocapture) #15

declare void @CJ_MCC_CheckThreadLocalDataOffset() local_unnamed_addr

declare void @CJ_MRT_CjRuntimeStart(i32 ()* %0) local_unnamed_addr

; Function Attrs: nounwind
declare void @llvm.cj.memset.p0i8(i8* %0, i8 %1, i64 %2, i1 %3) #17

declare void @CJ_MCC_C2NStub(...) #22

declare void @CJ_MCC_N2CStub(...) #22

declare i8 addrspace(1)* @CJ_MCC_NewObjectFast(i8* %0, i32 %1) #22


declare i8 addrspace(1)* @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)* %0) #22

declare i8 addrspace(1)* @CJ_MCC_NewObject(i8* %0, i32 %1) #23

declare void @CJ_MCC_ThrowException(i8 addrspace(1)* %0) #23

declare void @CJ_MCC_ThrowArithmeticException() local_unnamed_addr

declare i8 addrspace(1)* @CJ_MCC_NewArray(i8* %0, i64 %1) #23

declare i8* @CJ_MCC_GetExceptionWrapper() #22

declare i8 addrspace(1)* @CJ_MCC_BeginCatch(i8* %0) #22

declare void @CJ_MCC_EndCatch() #22

declare i1 @CJ_MCC_IsInstanceOf(i8 addrspace(1)* %0, i8* %1) #22

declare i8* @CJ_MCC_GetObjClass(i8 addrspace(1)* %0) local_unnamed_addr

declare i8* @CJ_MCC_GetFuncPtrFromItab(i64* %0, i32 %1, i32 %2, i8* %3) local_unnamed_addr

!0 = !{!"ArrayLayout.refArray"}
!1 = !{!"ObjLayout._ZN7default3ObjE"}

attributes #0 = { "CFileKlass" }
attributes #1 = { "CFileVTable" }
attributes #2 = { "CFileITable" }
attributes #3 = { "GCRoot" }
attributes #4 = { "CFileReflect" }
attributes #5 = { "cj-native" }
attributes #6 = { noinline }
attributes #7 = { mustprogress nofree noinline norecurse nosync nounwind willreturn writeonly }
attributes #8 = { "hasMD" }
attributes #9 = { "hasRcdParam" }
attributes #10 = { noinline "cjinit" }
attributes #11 = { "hasMD" "hasRcdParam" }
attributes #12 = { "UsedByClosure" }
attributes #13 = { noinline "cjinit" "hasMD" }
attributes #14 = { "cjinit" "hasMD" }
attributes #15 = { argmemonly nounwind }
attributes #16 = { argmemonly mustprogress nocallback nofree nounwind willreturn }
attributes #17 = { nounwind }
attributes #18 = { argmemonly mustprogress nocallback nofree nounwind willreturn writeonly }
attributes #19 = { mustprogress nocallback nofree nosync nounwind readnone speculatable willreturn }
attributes #20 = { noinline "hasMD" }
attributes #21 = { noinline "cj2c" }
attributes #22 = { "cj-runtime" "gc-leaf-function" }
attributes #23 = { "cj-runtime" }
