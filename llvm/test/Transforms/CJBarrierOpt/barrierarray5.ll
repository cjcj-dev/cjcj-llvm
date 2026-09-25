; RUN: opt --cj-barrier-opt -S < %s | FileCheck %s
; RUN: opt -passes=cj-barrier-opt -S < %s | FileCheck %s

%"record._ZN7default11std$FS$core5ArrayIN_ZN11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEEE" = type { i8 addrspace(1)*, i64, i64 }
%"record._ZN7default11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEE" = type { i1, %"T2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEE" }
%"T2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEE" = type { %Unit.Type, %"record._ZN7default11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEE" }
%"record._ZN7default11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEE" = type { i1, %"record._ZN7default11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEE" }
%Unit.Type = type { i8 }
%"record._ZN7default11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEE" = type { i1, %"record._ZN7default11std$FS$core6OptionIbE" }
%"record._ZN7default11std$FS$core6OptionIbE" = type { i1, i1 }
%_ZN07ClosureE = type { i8*, i8 addrspace(1)* }
%"ArrayLayout._ZN7default11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEE" = type { %ArrayBase, [0 x %"record._ZN7default11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEE"] }
%ArrayBase = type { %ObjLayout.Object, i64 }
%ObjLayout.Object = type { %KlassInfo.0* }
%KlassInfo.0 = type { i32, i32, %BitMap*, i8*, i8**, i64*, i64*, i8*, i64*, i32, [0 x i8*] }
%BitMap = type { i32, [0 x i8] }

@"_ZN11std$FS$core25IndexOutOfBoundsExceptionE.objKlass" = external global %KlassInfo.0
@"_ZN11std$FS$core26NegativeArraySizeExceptionE.objKlass" = external global %KlassInfo.0
@"A1_N_ZN11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEEE.typeName" = weak_odr global [115 x i8] c"A1_N_ZN11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEEE\00", align 1
@"_ZN7default11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEE.arrayKlass" = weak_odr hidden local_unnamed_addr global %KlassInfo.0 { i32 2, i32 6, %BitMap* null, i8* bitcast (%KlassInfo.0* @"record._ZN7default11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEE.structKlass" to i8*), i8** null, i64* null, i64* null, i8* null, i64* bitcast ([115 x i8]* @"A1_N_ZN11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEEE.typeName" to i64*), i32 0, [0 x i8*] zeroinitializer }
@"record._ZN7default11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEE.structKlass" = weak_odr hidden global %KlassInfo.0 { i32 8, i32 6, %BitMap* inttoptr (i64 -9223372036854775808 to %BitMap*), i8* null, i8** null, i64* null, i64* null, i8* null, i64* @"record._ZN7default11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEE.uniqueAddr", i32 0, [0 x i8*] zeroinitializer }
@"record._ZN7default11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEE.uniqueAddr" = weak_odr hidden global i64 0

declare i8 addrspace(1)* @CJ_MCC_NewArrayStub(i64, i8*)
declare i8 addrspace(1)* @CJ_MCC_NewObjectStub(i8*, i32)
declare void @CJ_MCC_StackCheck()
declare void @CJ_MCC_ThrowException(i8 addrspace(1)*)
declare void @MCC_SafepointStub()
declare void @"_ZN11std$FS$core25IndexOutOfBoundsException6<init>Ev"(i8 addrspace(1)*)
declare void @"_ZN11std$FS$core26NegativeArraySizeException6<init>Ev"(i8 addrspace(1)*)
declare void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)*, i8 addrspace(1)*, i8*, i64)
declare void @llvm.lifetime.end.p0i8(i64, i8*)
declare void @llvm.lifetime.start.p0i8(i64, i8*)
declare void @llvm.memset.p0i8.i64(i8*, i8, i64, i1)

; CHECK: call void @llvm.cj.gcwrite.struct.p0i8.i64(i8 addrspace(1)* %3, i8 addrspace(1)* %7, i8* nonnull %.sub, i64 6)
; CHECK: call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 8 %20, i8* align 8 %9, i64 6, i1 false)

define internal void @foo(i8 addrspace(1)* nocapture readnone %"__auto_v_889$BP", %"record._ZN7default11std$FS$core5ArrayIN_ZN11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEEE" addrspace(1)* nocapture writeonly %this, i64 %size, i8 addrspace(1)* nocapture readnone %"initElement$BP", %_ZN07ClosureE addrspace(1)* nocapture readonly %initElement) gc "cangjie" {
entry:
  call void @CJ_MCC_StackCheck()
  %callRet.i = alloca %"record._ZN7default11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEE", align 8
  %0 = alloca [6 x i8], align 8
  call cangjiegccc void @MCC_SafepointStub()
  %.sub = getelementptr inbounds [6 x i8], [6 x i8]* %0, i64 0, i64 0
  %1 = getelementptr inbounds %"record._ZN7default11std$FS$core5ArrayIN_ZN11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEEE", %"record._ZN7default11std$FS$core5ArrayIN_ZN11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEEE" addrspace(1)* %this, i64 0, i32 1
  store i64 0, i64 addrspace(1)* %1, align 8
  call void @llvm.memset.p0i8.i64(i8* noundef nonnull align 8 dereferenceable(6) %.sub, i8 0, i64 6, i1 false)
  %arr.alloc.size.valid = icmp sgt i64 %size, -1
  br i1 %arr.alloc.size.valid, label %arr.alloc.body, label %arr.alloc.throw

arr.alloc.throw:                                  ; preds = %entry
  %2 = tail call noalias i8 addrspace(1)* @CJ_MCC_NewObjectStub(i8* bitcast (%KlassInfo.0* @"_ZN11std$FS$core26NegativeArraySizeExceptionE.objKlass" to i8*), i32 72)
  tail call void @"_ZN11std$FS$core26NegativeArraySizeException6<init>Ev"(i8 addrspace(1)* %2)
  tail call void @CJ_MCC_ThrowException(i8 addrspace(1)* %2)
  unreachable

arr.alloc.body:                                   ; preds = %entry
  %3 = tail call noalias i8 addrspace(1)* @CJ_MCC_NewArrayStub(i64 %size, i8* bitcast (%KlassInfo.0* @"_ZN7default11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEE.arrayKlass" to i8*))
  %size.is-zero = icmp eq i64 %size, 0
  br i1 %size.is-zero, label %arr.init.opt, label %arr.init.body.preheader

arr.init.body.preheader:                          ; preds = %arr.alloc.body
  %4 = getelementptr inbounds i8, i8 addrspace(1)* %3, i64 16
  %5 = bitcast i8 addrspace(1)* %4 to %"record._ZN7default11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEE" addrspace(1)*
  br label %arr.init.body

arr.init.body:                                    ; preds = %arr.init.body.preheader, %arr.init.body
  %iterator.0 = phi i64 [ %8, %arr.init.body ], [ 0, %arr.init.body.preheader ]
  %6 = getelementptr inbounds %"record._ZN7default11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEE", %"record._ZN7default11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEE" addrspace(1)* %5, i64 %iterator.0
  %7 = bitcast %"record._ZN7default11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEE" addrspace(1)* %6 to i8 addrspace(1)*
  call void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)* %3, i8 addrspace(1)* %7, i8* nonnull %.sub, i64 6)
  %8 = add nuw nsw i64 %iterator.0, 1
  %exitcond.not = icmp eq i64 %8, %size
  call cangjiegccc void @MCC_SafepointStub()
  br i1 %exitcond.not, label %arr.init.opt, label %arr.init.body

arr.init.opt:                                     ; preds = %arr.init.body, %arr.alloc.body
  %9 = bitcast %"record._ZN7default11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEE"* %callRet.i to i8*
  call void @llvm.lifetime.start.p0i8(i64 6, i8* nonnull %9)
  %10 = getelementptr inbounds i8, i8 addrspace(1)* %3, i64 8
  %11 = bitcast i8 addrspace(1)* %10 to i64 addrspace(1)*
  %12 = load i64, i64 addrspace(1)* %11, align 8
  %icmpslt6.i = icmp sgt i64 %12, 0
  br i1 %icmpslt6.i, label %while.body.lr.ph.i, label %"_ZN7default11std$FS$core19arrayInitByFunctionIN_ZN11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEEEA1_N_ZN11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEEEC_ZN0126$LambdaCommon_1N_ZN11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEElE.exit"

while.body.lr.ph.i:                               ; preds = %arr.init.opt
  %13 = bitcast %_ZN07ClosureE addrspace(1)* %initElement to void (%"record._ZN7default11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEE"*, i8 addrspace(1)*, i64)* addrspace(1)*
  %14 = getelementptr inbounds %_ZN07ClosureE, %_ZN07ClosureE addrspace(1)* %initElement, i64 0, i32 1
  %15 = bitcast i8 addrspace(1)* %3 to %"ArrayLayout._ZN7default11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEE" addrspace(1)*
  br label %while.body.i

while.body.i:                                     ; preds = %arr.if.else.i, %while.body.lr.ph.i
  %atom.07.i = phi i64 [ 0, %while.body.lr.ph.i ], [ %add.i, %arr.if.else.i ]
  %16 = load void (%"record._ZN7default11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEE"*, i8 addrspace(1)*, i64)*, void (%"record._ZN7default11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEE"*, i8 addrspace(1)*, i64)* addrspace(1)* %13, align 8
  %17 = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %14, align 8
  call void %16(%"record._ZN7default11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEE"* noalias nonnull sret(%"record._ZN7default11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEE") %callRet.i, i8 addrspace(1)* %17, i64 %atom.07.i)
  %18 = load i64, i64 addrspace(1)* %11, align 8
  %.not.i = icmp slt i64 %atom.07.i, %18
  br i1 %.not.i, label %arr.if.else.i, label %arr.if.then.i

arr.if.then.i:                                    ; preds = %while.body.i
  %19 = call noalias i8 addrspace(1)* @CJ_MCC_NewObjectStub(i8* bitcast (%KlassInfo.0* @"_ZN11std$FS$core25IndexOutOfBoundsExceptionE.objKlass" to i8*), i32 72)
  call void @"_ZN11std$FS$core25IndexOutOfBoundsException6<init>Ev"(i8 addrspace(1)* %19)
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %19)
  unreachable

arr.if.else.i:                                    ; preds = %while.body.i
  %arr.idx.set.gep.i = getelementptr inbounds %"ArrayLayout._ZN7default11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEE", %"ArrayLayout._ZN7default11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEE" addrspace(1)* %15, i64 0, i32 1, i64 %atom.07.i
  %20 = bitcast %"record._ZN7default11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEE" addrspace(1)* %arr.idx.set.gep.i to i8 addrspace(1)*
  call void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)* %3, i8 addrspace(1)* %20, i8* nonnull %9, i64 6)
  %add.i = add nuw nsw i64 %atom.07.i, 1
  %21 = load i64, i64 addrspace(1)* %11, align 8
  %icmpslt.i = icmp slt i64 %add.i, %21
  call cangjiegccc void @MCC_SafepointStub()
  br i1 %icmpslt.i, label %while.body.i, label %"_ZN7default11std$FS$core19arrayInitByFunctionIN_ZN11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEEEA1_N_ZN11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEEEC_ZN0126$LambdaCommon_1N_ZN11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEElE.exit"

"_ZN7default11std$FS$core19arrayInitByFunctionIN_ZN11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEEEA1_N_ZN11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEEEC_ZN0126$LambdaCommon_1N_ZN11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEElE.exit": ; preds = %arr.if.else.i, %arr.init.opt
  call void @llvm.lifetime.end.p0i8(i64 6, i8* nonnull %9)
  %22 = getelementptr inbounds %"record._ZN7default11std$FS$core5ArrayIN_ZN11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEEE", %"record._ZN7default11std$FS$core5ArrayIN_ZN11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEEE" addrspace(1)* %this, i64 0, i32 0
  store i8 addrspace(1)* %3, i8 addrspace(1)* addrspace(1)* %22, align 8
  %23 = getelementptr inbounds %"record._ZN7default11std$FS$core5ArrayIN_ZN11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEEE", %"record._ZN7default11std$FS$core5ArrayIN_ZN11std$FS$core6OptionIT2_uN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIN_ZN11std$FS$core6OptionIbEEEEEE" addrspace(1)* %this, i64 0, i32 2
  store i64 %size, i64 addrspace(1)* %23, align 8
  ret void
}
