; RUN: llvm-as %s -o %t.bc
; RUN: llvm-link %t.bc -S | FileCheck %s

; CHECK:         %KlassInfo.0 = type { i32, i32, %BitMap*, i8*, i8**, i64*, i64*, i64*, i32, [0 x i8*] }
; CHECK-NEXT:    %BitMap = type { i32, [0 x i8] }
; CHECK-NEXT:    %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" = type { i8 addrspace(1)*, i64, i64 }
; CHECK-NEXT:    %KlassInfo.1 = type { i32, i32, %BitMap*, i8*, i8**, i64*, i64*, i64*, i32, [1 x i8*] }
; CHECK-NEXT:    %"record._ZN11std$FS$core6StringE" = type { i8 addrspace(1)*, i64 }
%KlassInfo.0 = type { i32, i32, %BitMap*, i8*, i8**, i64*, i64*, i64*, i32, [0 x i8*] }
%BitMap = type { i32, [0 x i8] }
%KlassInfo.1 = type { i32, i32, %BitMap*, i8*, i8**, i64*, i64*, i64*, i32, [1 x i8*] }
%"record._ZN11std$FS$core11std$FS$core5ArrayIhE" = type { i8 addrspace(1)*, i64, i64 }
%"record._ZN11std$FS$core11std$FS$core5ArrayIlE" = type { i8 addrspace(1)*, i64, i64 }
%"record._ZN11std$FS$core11std$FS$core5ArrayIR_ZN11std$FS$core6StringEE" = type { i8 addrspace(1)*, i64, i64 }
%"record._ZN11std$FS$core11std$FS$core5ArrayIC_ZN11std$FS$core17StackTraceElementEE" = type { i8 addrspace(1)*, i64, i64 }
%"record._ZN11std$FS$core6StringE" = type { i8 addrspace(1)*, i64 }

; CHECK:         @Int64.arrayKlass = weak_odr global %KlassInfo.0 { i32 2, i32 8, %BitMap* null, i8* bitcast (%KlassInfo.0* @array_int64.primKlass to i8*), i8** null, i64* null, i64* null, i64* bitcast ([6 x i8]* @A1_lE.className to i64*), i32 0, [0 x i8*] zeroinitializer } #0
; CHECK-NEXT:    @A1_lE.className = weak_odr global [6 x i8] c"A1_lE\00", align 1
; CHECK-NEXT:    @array_int64.primKlass = weak_odr global %KlassInfo.0 { i32 1, i32 8, %BitMap* null, i8* null, i8** null, i64* null, i64* null, i64* @array_int64.uniqueAddr, i32 0, [0 x i8*] zeroinitializer } #0
; CHECK-NEXT:    @array_int64.uniqueAddr = weak_odr global i64 0
; CHECK-NEXT:    @UInt8.arrayKlass = weak_odr global %KlassInfo.0 { i32 2, i32 1, %BitMap* null, i8* bitcast (%KlassInfo.0* @array_uint8.primKlass to i8*), i8** null, i64* null, i64* null, i64* bitcast ([6 x i8]* @A1_hE.className to i64*), i32 0, [0 x i8*] zeroinitializer } #0
; CHECK-NEXT:    @A1_hE.className = weak_odr global [6 x i8] c"A1_hE\00", align 1
; CHECK-NEXT:    @array_uint8.primKlass = weak_odr global %KlassInfo.0 { i32 1, i32 1, %BitMap* null, i8* null, i8** null, i64* null, i64* null, i64* @array_uint8.uniqueAddr, i32 0, [0 x i8*] zeroinitializer } #0
; CHECK-NEXT:    @array_uint8.uniqueAddr = weak_odr global i64 0
; CHECK-NEXT:    @"_ZN11std$FS$core17EMPTY_INT64_ARRAYE" = global %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" zeroinitializer, !GlobalVarType !0 #0
; CHECK-NEXT:    @"_ZN11std$FS$core17StackTraceElementE.objKlass" = weak_odr global %KlassInfo.0 { i32 36, i32 64, %BitMap* inttoptr (i64 -9223372036854775766 to %BitMap*), i8* bitcast (%KlassInfo.1* @"_ZN11std$FS$core6ObjectE.objKlass" to i8*), i8** null, i64* null, i64* null, i64* bitcast ([38 x i8]* @"C_ZN11std$FS$core17StackTraceElementE.className" to i64*), i32 0, [0 x i8*] zeroinitializer } #0
; CHECK-NEXT:    @"C_ZN11std$FS$core17StackTraceElementE.className" = internal global [38 x i8] c"C_ZN11std$FS$core17StackTraceElementE\00", align 1
; CHECK-NEXT:    @"_ZN11std$FS$core6ObjectE.objKlass" = weak_odr global %KlassInfo.1 { i32 4, i32 8, %BitMap* inttoptr (i64 -9223372036854775808 to %BitMap*), i8* bitcast (%KlassInfo.0* @Object.objKlass to i8*), i8** null, i64* null, i64* null, i64* bitcast ([26 x i8]* @"C_ZN11std$FS$core6ObjectE.className" to i64*), i32 1, [1 x i8*] [i8* bitcast (%KlassInfo.0* @"_ZN11std$FS$core3AnyE.objKlass" to i8*)] } #0
; CHECK-NEXT:    @Object.objKlass = weak_odr global %KlassInfo.0 { i32 4, i32 8, %BitMap* inttoptr (i64 -9223372036854775808 to %BitMap*), i8* null, i8** null, i64* null, i64* null, i64* null, i32 0, [0 x i8*] zeroinitializer } #0
; CHECK-NEXT:    @"C_ZN11std$FS$core6ObjectE.className" = internal global [26 x i8] c"C_ZN11std$FS$core6ObjectE\00", align 1
; CHECK-NEXT:    @"_ZN11std$FS$core3AnyE.objKlass" = weak_odr global %KlassInfo.0 { i32 16, i32 8, %BitMap* inttoptr (i64 -9223372036854775808 to %BitMap*), i8* null, i8** null, i64* null, i64* null, i64* bitcast ([23 x i8]* @"C_ZN11std$FS$core3AnyE.className" to i64*), i32 0, [0 x i8*] zeroinitializer } #0
; CHECK-NEXT:    @"C_ZN11std$FS$core3AnyE.className" = internal global [23 x i8] c"C_ZN11std$FS$core3AnyE\00", align 1
; CHECK-NEXT:    @"_ZN11std$FS$core17StackTraceElementE.refArrayKlass" = internal global %KlassInfo.0 { i32 34, i32 8, %BitMap* null, i8* bitcast (%KlassInfo.0* @"_ZN11std$FS$core17StackTraceElementE.objKlass" to i8*), i8** null, i64* null, i64* null, i64* bitcast ([42 x i8]* @"A1_C_ZN11std$FS$core17StackTraceElementEE.className" to i64*), i32 0, [0 x i8*] zeroinitializer } #0
; CHECK-NEXT:    @"A1_C_ZN11std$FS$core17StackTraceElementEE.className" = weak_odr global [42 x i8] c"A1_C_ZN11std$FS$core17StackTraceElementEE\00", align 1
; CHECK-NEXT:    @"_ZN11std$FS$core18EMPTY_STRING_ARRAYE" = internal global %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" zeroinitializer, !GlobalVarType !1 #0
; CHECK-NEXT:    @"_ZN11std$FS$core21EMPTY_UINT8_RAW_ARRAYE" = internal global i8 addrspace(1)* null, !GlobalVarType !2 #0
; CHECK-NEXT:    @"_ZN11std$FS$core6String5emptyE" = global %"record._ZN11std$FS$core6StringE" zeroinitializer, !GlobalVarType !3 #0
; CHECK-NEXT:    @"_ZN11std$FS$core6StringE.arrayKlass" = weak_odr global %KlassInfo.0 { i32 34, i32 16, %BitMap* null, i8* bitcast (%KlassInfo.0* @"record._ZN11std$FS$core6StringE.structKlass" to i8*), i8** null, i64* null, i64* null, i64* bitcast ([30 x i8]* @"A1_R_ZN11std$FS$core6StringEE.className" to i64*), i32 0, [0 x i8*] zeroinitializer } #0
; CHECK-NEXT:    @"A1_R_ZN11std$FS$core6StringEE.className" = weak_odr global [30 x i8] c"A1_R_ZN11std$FS$core6StringEE\00", align 1
; CHECK-NEXT:    @"record._ZN11std$FS$core6StringE.structKlass" = weak_odr global %KlassInfo.0 { i32 40, i32 16, %BitMap* inttoptr (i64 -9223372036854775807 to %BitMap*), i8* null, i8** null, i64* null, i64* null, i64* @"record._ZN11std$FS$core6StringE.uniqueAddr", i32 0, [0 x i8*] zeroinitializer } #0
; CHECK-NEXT:    @"record._ZN11std$FS$core6StringE.uniqueAddr" = weak_odr global i64 0
; CHECK-NEXT:    @"_ZN11std$FS$core17EMPTY_UINT8_ARRAYE" = global %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" zeroinitializer, !GlobalVarType !4 #0
@Int64.arrayKlass = weak_odr global %KlassInfo.0 { i32 2, i32 8, %BitMap* null, i8* bitcast (%KlassInfo.0* @array_int64.primKlass to i8*), i8** null, i64* null, i64* null, i64* bitcast ([6 x i8]* @A1_lE.className to i64*), i32 0, [0 x i8*] zeroinitializer } #0
@A1_lE.className = weak_odr global [6 x i8] c"A1_lE\00", align 1
@array_int64.primKlass = weak_odr global %KlassInfo.0 { i32 1, i32 8, %BitMap* null, i8* null, i8** null, i64* null, i64* null, i64* @array_int64.uniqueAddr, i32 0, [0 x i8*] zeroinitializer } #0
@array_int64.uniqueAddr = weak_odr global i64 0
@UInt8.arrayKlass = weak_odr global %KlassInfo.0 { i32 2, i32 1, %BitMap* null, i8* bitcast (%KlassInfo.0* @array_uint8.primKlass to i8*), i8** null, i64* null, i64* null, i64* bitcast ([6 x i8]* @A1_hE.className to i64*), i32 0, [0 x i8*] zeroinitializer } #0
@A1_hE.className = weak_odr global [6 x i8] c"A1_hE\00", align 1
@array_uint8.primKlass = weak_odr global %KlassInfo.0 { i32 1, i32 1, %BitMap* null, i8* null, i8** null, i64* null, i64* null, i64* @array_uint8.uniqueAddr, i32 0, [0 x i8*] zeroinitializer } #0
@array_uint8.uniqueAddr = weak_odr global i64 0
@"_ZN11std$FS$core17EMPTY_INT64_ARRAYE" = global %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" zeroinitializer, !GlobalVarType !2 #0
@"_ZN11std$FS$core17StackTraceElementE.objKlass" = weak_odr global %KlassInfo.0 { i32 36, i32 64, %BitMap* inttoptr (i64 -9223372036854775766 to %BitMap*), i8* bitcast (%KlassInfo.1* @"_ZN11std$FS$core6ObjectE.objKlass" to i8*), i8** null, i64* null, i64* null, i64* bitcast ([38 x i8]* @"C_ZN11std$FS$core17StackTraceElementE.className" to i64*), i32 0, [0 x i8*] zeroinitializer } #0
@"C_ZN11std$FS$core17StackTraceElementE.className" = internal global [38 x i8] c"C_ZN11std$FS$core17StackTraceElementE\00", align 1
@"_ZN11std$FS$core6ObjectE.objKlass" = weak_odr global %KlassInfo.1 { i32 4, i32 8, %BitMap* inttoptr (i64 -9223372036854775808 to %BitMap*), i8* bitcast (%KlassInfo.0* @Object.objKlass to i8*), i8** null, i64* null, i64* null, i64* bitcast ([26 x i8]* @"C_ZN11std$FS$core6ObjectE.className" to i64*), i32 1, [1 x i8*] [i8* bitcast (%KlassInfo.0* @"_ZN11std$FS$core3AnyE.objKlass" to i8*)] } #0
@Object.objKlass = weak_odr global %KlassInfo.0 { i32 4, i32 8, %BitMap* inttoptr (i64 -9223372036854775808 to %BitMap*), i8* null, i8** null, i64* null, i64* null, i64* null, i32 0, [0 x i8*] zeroinitializer } #0
@"C_ZN11std$FS$core6ObjectE.className" = internal global [26 x i8] c"C_ZN11std$FS$core6ObjectE\00", align 1
@"_ZN11std$FS$core3AnyE.objKlass" = weak_odr global %KlassInfo.0 { i32 16, i32 8, %BitMap* inttoptr (i64 -9223372036854775808 to %BitMap*), i8* null, i8** null, i64* null, i64* null, i64* bitcast ([23 x i8]* @"C_ZN11std$FS$core3AnyE.className" to i64*), i32 0, [0 x i8*] zeroinitializer } #0
@"C_ZN11std$FS$core3AnyE.className" = internal global [23 x i8] c"C_ZN11std$FS$core3AnyE\00", align 1
@"_ZN11std$FS$core17StackTraceElementE.refArrayKlass" = internal global %KlassInfo.0 { i32 34, i32 8, %BitMap* null, i8* bitcast (%KlassInfo.0* @"_ZN11std$FS$core17StackTraceElementE.objKlass" to i8*), i8** null, i64* null, i64* null, i64* bitcast ([42 x i8]* @"A1_C_ZN11std$FS$core17StackTraceElementEE.className" to i64*), i32 0, [0 x i8*] zeroinitializer } #0
@"A1_C_ZN11std$FS$core17StackTraceElementEE.className" = weak_odr global [42 x i8] c"A1_C_ZN11std$FS$core17StackTraceElementEE\00", align 1
@"_ZN11std$FS$core18EMPTY_STRING_ARRAYE" = internal global %"record._ZN11std$FS$core11std$FS$core5ArrayIR_ZN11std$FS$core6StringEE" zeroinitializer, !GlobalVarType !3 #0
@"_ZN11std$FS$core21EMPTY_UINT8_RAW_ARRAYE" = internal global i8 addrspace(1)* null, !GlobalVarType !1 #0
@"_ZN11std$FS$core6String5emptyE" = global %"record._ZN11std$FS$core6StringE" zeroinitializer, !GlobalVarType !4 #0
@"_ZN11std$FS$core6StringE.arrayKlass" = weak_odr global %KlassInfo.0 { i32 34, i32 16, %BitMap* null, i8* bitcast (%KlassInfo.0* @"record._ZN11std$FS$core6StringE.structKlass" to i8*), i8** null, i64* null, i64* null, i64* bitcast ([30 x i8]* @"A1_R_ZN11std$FS$core6StringEE.className" to i64*), i32 0, [0 x i8*] zeroinitializer } #0
@"A1_R_ZN11std$FS$core6StringEE.className" = weak_odr global [30 x i8] c"A1_R_ZN11std$FS$core6StringEE\00", align 1
@"record._ZN11std$FS$core6StringE.structKlass" = weak_odr global %KlassInfo.0 { i32 40, i32 16, %BitMap* inttoptr (i64 -9223372036854775807 to %BitMap*), i8* null, i8** null, i64* null, i64* null, i64* @"record._ZN11std$FS$core6StringE.uniqueAddr", i32 0, [0 x i8*] zeroinitializer } #0
@"record._ZN11std$FS$core6StringE.uniqueAddr" = weak_odr global i64 0


declare i8 addrspace(1)* @CJ_MCC_DecodeStackTrace(i8 addrspace(1)*, i8*, i8*, i8*)
declare i8 addrspace(1)* @CJ_MCC_NewArray64Stub(i64, i8*)
declare i8 addrspace(1)* @CJ_MCC_NewArray8Stub(i64, i8*)
declare i8 addrspace(1)* @CJ_MCC_NewArrayStub(i64, i8*)
declare void @llvm.cj.gcwrite.static(i8 addrspace(1)*, i8 addrspace(1)** nocapture)
declare void @llvm.cj.gcwrite.static.struct(i8* noalias nocapture writeonly, i8* noalias nocapture readonly, i64)
declare void @llvm.cj.memset.p0i8(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8* noalias nocapture writeonly, i8* noalias nocapture readonly, i64, i1 immarg)


@"_ZN11std$FS$core17EMPTY_UINT8_ARRAYE" = global %"record._ZN11std$FS$core11std$FS$core5ArrayIhE" zeroinitializer, !GlobalVarType !0 #0

define void @foo1() unnamed_addr gc "cangjie" {
; CHECK-LABEL: @foo1(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[ENUMTMP3:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[TMP0:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[TMP13877E:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[ENUMTMP2:%.*]] = alloca %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", align 8
; CHECK-NEXT:    [[TMP1:%.*]] = alloca %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", align 8
; CHECK-NEXT:    [[TMP13032E:%.*]] = alloca %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", align 8
; CHECK-NEXT:    [[ENUMTMP1:%.*]] = alloca %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", align 8
; CHECK-NEXT:    [[TMP2:%.*]] = alloca %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", align 8
; CHECK-NEXT:    [[TMP12978E:%.*]] = alloca %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", align 8
; CHECK-NEXT:    [[ENUMTMP:%.*]] = alloca %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", align 8
; CHECK-NEXT:    [[TMP3:%.*]] = alloca %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", align 8
; CHECK-NEXT:    [[TMP12957E:%.*]] = alloca %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", align 8
; CHECK-NEXT:    [[ENUMTMP3_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[ENUMTMP3]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[ENUMTMP3_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[DOT0_SROA_CAST3:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[TMP0]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[DOT0_SROA_CAST3]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[TMP4:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[TMP13877E]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull align 8 [[TMP4]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[ENUMTMP2_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[ENUMTMP2]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[ENUMTMP2_0_SROA_CAST]], i8 0, i64 24, i1 false)
; CHECK-NEXT:    [[DOT0_SROA_CAST2:%.*]] = bitcast %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[TMP1]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[DOT0_SROA_CAST2]], i8 0, i64 24, i1 false)
; CHECK-NEXT:    [[TMP5:%.*]] = bitcast %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[TMP13032E]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull align 8 [[TMP5]], i8 0, i64 24, i1 false)
; CHECK-NEXT:    [[ENUMTMP1_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[ENUMTMP1]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[ENUMTMP1_0_SROA_CAST]], i8 0, i64 24, i1 false)
; CHECK-NEXT:    [[DOT0_SROA_CAST1:%.*]] = bitcast %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[TMP2]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[DOT0_SROA_CAST1]], i8 0, i64 24, i1 false)
; CHECK-NEXT:    [[TMP6:%.*]] = bitcast %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[TMP12978E]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull align 8 [[TMP6]], i8 0, i64 24, i1 false)
; CHECK-NEXT:    [[ENUMTMP_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[ENUMTMP]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[ENUMTMP_0_SROA_CAST]], i8 0, i64 24, i1 false)
; CHECK-NEXT:    [[DOT0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[TMP3]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[DOT0_SROA_CAST]], i8 0, i64 24, i1 false)
; CHECK-NEXT:    [[TMP7:%.*]] = bitcast %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[TMP12957E]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull align 8 [[TMP7]], i8 0, i64 24, i1 false)
; CHECK-NEXT:    call void @llvm.memcpy.p0i8.p0i8.i64(i8* noundef nonnull align 8 dereferenceable(24) [[TMP7]], i8* noundef nonnull align 8 dereferenceable(24) [[DOT0_SROA_CAST]], i64 24, i1 false)
; CHECK-NEXT:    [[TMP8:%.*]] = addrspacecast %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[TMP12957E]] to %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)*
; CHECK-NEXT:    [[TMP9:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)* [[TMP8]], i64 0, i32 1
; CHECK-NEXT:    store i64 0, i64 addrspace(1)* [[TMP9]], align 4
; CHECK-NEXT:    [[TMP10:%.*]] = call noalias i8 addrspace(1)* @CJ_MCC_NewArray8Stub(i64 0, i8* bitcast (%KlassInfo.0* @UInt8.arrayKlass to i8*))
; CHECK-NEXT:    [[TMP11:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)* [[TMP8]], i64 0, i32 0
; CHECK-NEXT:    store i8 addrspace(1)* [[TMP10]], i8 addrspace(1)* addrspace(1)* [[TMP11]], align 8
; CHECK-NEXT:    [[TMP12:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)* [[TMP8]], i64 0, i32 2
; CHECK-NEXT:    store i64 0, i64 addrspace(1)* [[TMP12]], align 4
; CHECK-NEXT:    call void @llvm.cj.gcwrite.static.struct.i64(i8* bitcast (%"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* @"_ZN11std$FS$core17EMPTY_UINT8_ARRAYE" to i8*), i8* nonnull [[TMP7]], i64 24), !AggType !6
; CHECK-NEXT:    [[TMP13:%.*]] = call noalias i8 addrspace(1)* @CJ_MCC_NewArray8Stub(i64 0, i8* bitcast (%KlassInfo.0* @UInt8.arrayKlass to i8*))
; CHECK-NEXT:    call void @llvm.cj.gcwrite.static(i8 addrspace(1)* [[TMP13]], i8 addrspace(1)** nonnull @"_ZN11std$FS$core21EMPTY_UINT8_RAW_ARRAYE")
; CHECK-NEXT:    call void @llvm.memcpy.p0i8.p0i8.i64(i8* noundef nonnull align 8 dereferenceable(24) [[TMP6]], i8* noundef nonnull align 8 dereferenceable(24) [[DOT0_SROA_CAST1]], i64 24, i1 false)
; CHECK-NEXT:    [[TMP14:%.*]] = addrspacecast %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[TMP12978E]] to %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)*
; CHECK-NEXT:    [[TMP15:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)* [[TMP14]], i64 0, i32 1
; CHECK-NEXT:    store i64 0, i64 addrspace(1)* [[TMP15]], align 4
; CHECK-NEXT:    [[TMP16:%.*]] = call noalias i8 addrspace(1)* @CJ_MCC_NewArray64Stub(i64 0, i8* bitcast (%KlassInfo.0* @Int64.arrayKlass to i8*))
; CHECK-NEXT:    [[TMP17:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)* [[TMP14]], i64 0, i32 0
; CHECK-NEXT:    store i8 addrspace(1)* [[TMP16]], i8 addrspace(1)* addrspace(1)* [[TMP17]], align 8
; CHECK-NEXT:    [[TMP18:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)* [[TMP14]], i64 0, i32 2
; CHECK-NEXT:    store i64 0, i64 addrspace(1)* [[TMP18]], align 4
; CHECK-NEXT:    call void @llvm.cj.gcwrite.static.struct.i64(i8* bitcast (%"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* @"_ZN11std$FS$core17EMPTY_INT64_ARRAYE" to i8*), i8* nonnull [[TMP6]], i64 24), !AggType !7
; CHECK-NEXT:    call void @llvm.memcpy.p0i8.p0i8.i64(i8* noundef nonnull align 8 dereferenceable(24) [[TMP5]], i8* noundef nonnull align 8 dereferenceable(24) [[DOT0_SROA_CAST2]], i64 24, i1 false)
; CHECK-NEXT:    [[TMP19:%.*]] = addrspacecast %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[TMP13032E]] to %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)*
; CHECK-NEXT:    [[TMP20:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)* [[TMP19]], i64 0, i32 1
; CHECK-NEXT:    store i64 0, i64 addrspace(1)* [[TMP20]], align 4
; CHECK-NEXT:    [[TMP21:%.*]] = call noalias i8 addrspace(1)* @CJ_MCC_NewArrayStub(i64 0, i8* bitcast (%KlassInfo.0* @"_ZN11std$FS$core6StringE.arrayKlass" to i8*))
; CHECK-NEXT:    [[TMP22:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)* [[TMP19]], i64 0, i32 0
; CHECK-NEXT:    store i8 addrspace(1)* [[TMP21]], i8 addrspace(1)* addrspace(1)* [[TMP22]], align 8
; CHECK-NEXT:    [[TMP23:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)* [[TMP19]], i64 0, i32 2
; CHECK-NEXT:    store i64 0, i64 addrspace(1)* [[TMP23]], align 4
; CHECK-NEXT:    call void @llvm.cj.gcwrite.static.struct.i64(i8* bitcast (%"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* @"_ZN11std$FS$core18EMPTY_STRING_ARRAYE" to i8*), i8* nonnull [[TMP5]], i64 24), !AggType !8
; CHECK-NEXT:    [[TMP24:%.*]] = addrspacecast %"record._ZN11std$FS$core6StringE"* [[TMP13877E]] to %"record._ZN11std$FS$core6StringE" addrspace(1)*
; CHECK-NEXT:    [[TMP25:%.*]] = load i8 addrspace(1)*, i8 addrspace(1)** @"_ZN11std$FS$core21EMPTY_UINT8_RAW_ARRAYE", align 8
; CHECK-NEXT:    [[TMP26:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core6StringE", %"record._ZN11std$FS$core6StringE" addrspace(1)* [[TMP24]], i64 0, i32 0
; CHECK-NEXT:    store i8 addrspace(1)* [[TMP25]], i8 addrspace(1)* addrspace(1)* [[TMP26]], align 8
; CHECK-NEXT:    [[TMP27:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core6StringE", %"record._ZN11std$FS$core6StringE" addrspace(1)* [[TMP24]], i64 0, i32 1
; CHECK-NEXT:    store i64 0, i64 addrspace(1)* [[TMP27]], align 4
; CHECK-NEXT:    call void @llvm.cj.gcwrite.static.struct.i64(i8* bitcast (%"record._ZN11std$FS$core6StringE"* @"_ZN11std$FS$core6String5emptyE" to i8*), i8* nonnull [[TMP4]], i64 16), !AggType !9
; CHECK-NEXT:    ret void
;
entry:
  %enumTmp3 = alloca %"record._ZN11std$FS$core6StringE"
  %0 = alloca %"record._ZN11std$FS$core6StringE"
  %tmp13877E = alloca %"record._ZN11std$FS$core6StringE"
  %enumTmp2 = alloca %"record._ZN11std$FS$core11std$FS$core5ArrayIR_ZN11std$FS$core6StringEE"
  %1 = alloca %"record._ZN11std$FS$core11std$FS$core5ArrayIR_ZN11std$FS$core6StringEE"
  %tmp13032E = alloca %"record._ZN11std$FS$core11std$FS$core5ArrayIR_ZN11std$FS$core6StringEE"
  %enumTmp1 = alloca %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"
  %2 = alloca %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"
  %tmp12978E = alloca %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"
  %enumTmp = alloca %"record._ZN11std$FS$core11std$FS$core5ArrayIhE"
  %3 = alloca %"record._ZN11std$FS$core11std$FS$core5ArrayIhE"
  %tmp12957E = alloca %"record._ZN11std$FS$core11std$FS$core5ArrayIhE"
  %enumTmp3.0.sroa_cast = bitcast %"record._ZN11std$FS$core6StringE"* %enumTmp3 to i8*
  call void @llvm.cj.memset.p0i8(i8* nonnull %enumTmp3.0.sroa_cast, i8 0, i64 16, i1 false)
  %.0.sroa_cast3 = bitcast %"record._ZN11std$FS$core6StringE"* %0 to i8*
  call void @llvm.cj.memset.p0i8(i8* nonnull %.0.sroa_cast3, i8 0, i64 16, i1 false)
  %4 = bitcast %"record._ZN11std$FS$core6StringE"* %tmp13877E to i8*
  call void @llvm.cj.memset.p0i8(i8* nonnull align 8 %4, i8 0, i64 16, i1 false)
  %enumTmp2.0.sroa_cast = bitcast %"record._ZN11std$FS$core11std$FS$core5ArrayIR_ZN11std$FS$core6StringEE"* %enumTmp2 to i8*
  call void @llvm.cj.memset.p0i8(i8* nonnull %enumTmp2.0.sroa_cast, i8 0, i64 24, i1 false)
  %.0.sroa_cast2 = bitcast %"record._ZN11std$FS$core11std$FS$core5ArrayIR_ZN11std$FS$core6StringEE"* %1 to i8*
  call void @llvm.cj.memset.p0i8(i8* nonnull %.0.sroa_cast2, i8 0, i64 24, i1 false)
  %5 = bitcast %"record._ZN11std$FS$core11std$FS$core5ArrayIR_ZN11std$FS$core6StringEE"* %tmp13032E to i8*
  call void @llvm.cj.memset.p0i8(i8* nonnull align 8 %5, i8 0, i64 24, i1 false)
  %enumTmp1.0.sroa_cast = bitcast %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* %enumTmp1 to i8*
  call void @llvm.cj.memset.p0i8(i8* nonnull %enumTmp1.0.sroa_cast, i8 0, i64 24, i1 false)
  %.0.sroa_cast1 = bitcast %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* %2 to i8*
  call void @llvm.cj.memset.p0i8(i8* nonnull %.0.sroa_cast1, i8 0, i64 24, i1 false)
  %6 = bitcast %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* %tmp12978E to i8*
  call void @llvm.cj.memset.p0i8(i8* nonnull align 8 %6, i8 0, i64 24, i1 false)
  %enumTmp.0.sroa_cast = bitcast %"record._ZN11std$FS$core11std$FS$core5ArrayIhE"* %enumTmp to i8*
  call void @llvm.cj.memset.p0i8(i8* nonnull %enumTmp.0.sroa_cast, i8 0, i64 24, i1 false)
  %.0.sroa_cast = bitcast %"record._ZN11std$FS$core11std$FS$core5ArrayIhE"* %3 to i8*
  call void @llvm.cj.memset.p0i8(i8* nonnull %.0.sroa_cast, i8 0, i64 24, i1 false)
  %7 = bitcast %"record._ZN11std$FS$core11std$FS$core5ArrayIhE"* %tmp12957E to i8*
  call void @llvm.cj.memset.p0i8(i8* nonnull align 8 %7, i8 0, i64 24, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* noundef nonnull align 8 dereferenceable(24) %7, i8* noundef nonnull align 8 dereferenceable(24) %.0.sroa_cast, i64 24, i1 false)
  %8 = addrspacecast %"record._ZN11std$FS$core11std$FS$core5ArrayIhE"* %tmp12957E to %"record._ZN11std$FS$core11std$FS$core5ArrayIhE" addrspace(1)*
  %9 = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIhE", %"record._ZN11std$FS$core11std$FS$core5ArrayIhE" addrspace(1)* %8, i64 0, i32 1
  store i64 0, i64 addrspace(1)* %9
  %10 = call noalias i8 addrspace(1)* @CJ_MCC_NewArray8Stub(i64 0, i8* bitcast (%KlassInfo.0* @UInt8.arrayKlass to i8*))
  %11 = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIhE", %"record._ZN11std$FS$core11std$FS$core5ArrayIhE" addrspace(1)* %8, i64 0, i32 0
  store i8 addrspace(1)* %10, i8 addrspace(1)* addrspace(1)* %11
  %12 = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIhE", %"record._ZN11std$FS$core11std$FS$core5ArrayIhE" addrspace(1)* %8, i64 0, i32 2
  store i64 0, i64 addrspace(1)* %12
  call void @llvm.cj.gcwrite.static.struct(i8* bitcast (%"record._ZN11std$FS$core11std$FS$core5ArrayIhE"* @"_ZN11std$FS$core17EMPTY_UINT8_ARRAYE" to i8*), i8* nonnull %7, i64 24), !AggType !6
  %13 = call noalias i8 addrspace(1)* @CJ_MCC_NewArray8Stub(i64 0, i8* bitcast (%KlassInfo.0* @UInt8.arrayKlass to i8*))
  call void @llvm.cj.gcwrite.static(i8 addrspace(1)* %13, i8 addrspace(1)** nonnull @"_ZN11std$FS$core21EMPTY_UINT8_RAW_ARRAYE")
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* noundef nonnull align 8 dereferenceable(24) %6, i8* noundef nonnull align 8 dereferenceable(24) %.0.sroa_cast1, i64 24, i1 false)
  %14 = addrspacecast %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* %tmp12978E to %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)*
  %15 = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)* %14, i64 0, i32 1
  store i64 0, i64 addrspace(1)* %15
  %16 = call noalias i8 addrspace(1)* @CJ_MCC_NewArray64Stub(i64 0, i8* bitcast (%KlassInfo.0* @Int64.arrayKlass to i8*))
  %17 = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)* %14, i64 0, i32 0
  store i8 addrspace(1)* %16, i8 addrspace(1)* addrspace(1)* %17
  %18 = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)* %14, i64 0, i32 2
  store i64 0, i64 addrspace(1)* %18
  call void @llvm.cj.gcwrite.static.struct(i8* bitcast (%"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* @"_ZN11std$FS$core17EMPTY_INT64_ARRAYE" to i8*), i8* nonnull %6, i64 24), !AggType !7
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* noundef nonnull align 8 dereferenceable(24) %5, i8* noundef nonnull align 8 dereferenceable(24) %.0.sroa_cast2, i64 24, i1 false)
  %19 = addrspacecast %"record._ZN11std$FS$core11std$FS$core5ArrayIR_ZN11std$FS$core6StringEE"* %tmp13032E to %"record._ZN11std$FS$core11std$FS$core5ArrayIR_ZN11std$FS$core6StringEE" addrspace(1)*
  %20 = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIR_ZN11std$FS$core6StringEE", %"record._ZN11std$FS$core11std$FS$core5ArrayIR_ZN11std$FS$core6StringEE" addrspace(1)* %19, i64 0, i32 1
  store i64 0, i64 addrspace(1)* %20
  %21 = call noalias i8 addrspace(1)* @CJ_MCC_NewArrayStub(i64 0, i8* bitcast (%KlassInfo.0* @"_ZN11std$FS$core6StringE.arrayKlass" to i8*))
  %22 = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIR_ZN11std$FS$core6StringEE", %"record._ZN11std$FS$core11std$FS$core5ArrayIR_ZN11std$FS$core6StringEE" addrspace(1)* %19, i64 0, i32 0
  store i8 addrspace(1)* %21, i8 addrspace(1)* addrspace(1)* %22
  %23 = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIR_ZN11std$FS$core6StringEE", %"record._ZN11std$FS$core11std$FS$core5ArrayIR_ZN11std$FS$core6StringEE" addrspace(1)* %19, i64 0, i32 2
  store i64 0, i64 addrspace(1)* %23
  call void @llvm.cj.gcwrite.static.struct(i8* bitcast (%"record._ZN11std$FS$core11std$FS$core5ArrayIR_ZN11std$FS$core6StringEE"* @"_ZN11std$FS$core18EMPTY_STRING_ARRAYE" to i8*), i8* nonnull %5, i64 24), !AggType !8
  %24 = addrspacecast %"record._ZN11std$FS$core6StringE"* %tmp13877E to %"record._ZN11std$FS$core6StringE" addrspace(1)*
  %25 = load i8 addrspace(1)*, i8 addrspace(1)** @"_ZN11std$FS$core21EMPTY_UINT8_RAW_ARRAYE"
  %26 = getelementptr inbounds %"record._ZN11std$FS$core6StringE", %"record._ZN11std$FS$core6StringE" addrspace(1)* %24, i64 0, i32 0
  store i8 addrspace(1)* %25, i8 addrspace(1)* addrspace(1)* %26
  %27 = getelementptr inbounds %"record._ZN11std$FS$core6StringE", %"record._ZN11std$FS$core6StringE" addrspace(1)* %24, i64 0, i32 1
  store i64 0, i64 addrspace(1)* %27
  call void @llvm.cj.gcwrite.static.struct(i8* bitcast (%"record._ZN11std$FS$core6StringE"* @"_ZN11std$FS$core6String5emptyE" to i8*), i8* nonnull %4, i64 16), !AggType !5
  ret void
}

define void @foo2(%"record._ZN11std$FS$core11std$FS$core5ArrayIC_ZN11std$FS$core17StackTraceElementEE"* noalias nocapture writeonly sret(%"record._ZN11std$FS$core11std$FS$core5ArrayIC_ZN11std$FS$core17StackTraceElementEE") %0, i8 addrspace(1)* nocapture readonly %this) gc "cangjie" {
; CHECK-LABEL: @foo2(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP1:%.*]] = getelementptr inbounds i8, i8 addrspace(1)* [[THIS:%.*]], i64 24
; CHECK-NEXT:    [[TMP2:%.*]] = bitcast i8 addrspace(1)* [[TMP1]] to i8 addrspace(1)* addrspace(1)*
; CHECK-NEXT:    [[TMP3:%.*]] = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* [[TMP2]], align 8
; CHECK-NEXT:    [[TMP4:%.*]] = tail call i8 addrspace(1)* @CJ_MCC_DecodeStackTrace(i8 addrspace(1)* [[TMP3]], i8* bitcast (%KlassInfo.0* @"_ZN11std$FS$core17StackTraceElementE.objKlass" to i8*), i8* bitcast (%KlassInfo.0* @"_ZN11std$FS$core17StackTraceElementE.refArrayKlass" to i8*), i8* bitcast (%KlassInfo.0* @UInt8.arrayKlass to i8*))
; CHECK-NEXT:    [[TMP5:%.*]] = getelementptr inbounds i8, i8 addrspace(1)* [[TMP4]], i64 8
; CHECK-NEXT:    [[TMP6:%.*]] = bitcast i8 addrspace(1)* [[TMP5]] to i64 addrspace(1)*
; CHECK-NEXT:    [[TMP7:%.*]] = load i64, i64 addrspace(1)* [[TMP6]], align 4
; CHECK-NEXT:    [[ATOM_33641E_SROA_0_0__SROA_IDX2:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[TMP0:%.*]], i64 0, i32 0
; CHECK-NEXT:    store i8 addrspace(1)* [[TMP4]], i8 addrspace(1)** [[ATOM_33641E_SROA_0_0__SROA_IDX2]], align 8
; CHECK-NEXT:    [[ATOM_33641E_SROA_4_0__SROA_IDX5:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[TMP0]], i64 0, i32 1
; CHECK-NEXT:    store i64 0, i64* [[ATOM_33641E_SROA_4_0__SROA_IDX5]], align 4
; CHECK-NEXT:    [[ATOM_33641E_SROA_5_0__SROA_IDX8:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[TMP0]], i64 0, i32 2
; CHECK-NEXT:    store i64 [[TMP7]], i64* [[ATOM_33641E_SROA_5_0__SROA_IDX8]], align 4
; CHECK-NEXT:    ret void
;
entry:
  %1 = getelementptr inbounds i8, i8 addrspace(1)* %this, i64 24
  %2 = bitcast i8 addrspace(1)* %1 to i8 addrspace(1)* addrspace(1)*
  %3 = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %2
  %4 = tail call i8 addrspace(1)* @CJ_MCC_DecodeStackTrace(i8 addrspace(1)* %3, i8* bitcast (%KlassInfo.0* @"_ZN11std$FS$core17StackTraceElementE.objKlass" to i8*), i8* bitcast (%KlassInfo.0* @"_ZN11std$FS$core17StackTraceElementE.refArrayKlass" to i8*), i8* bitcast (%KlassInfo.0* @UInt8.arrayKlass to i8*))
  %5 = getelementptr inbounds i8, i8 addrspace(1)* %4, i64 8
  %6 = bitcast i8 addrspace(1)* %5 to i64 addrspace(1)*
  %7 = load i64, i64 addrspace(1)* %6
  %atom.33641E.sroa.0.0..sroa_idx2 = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIC_ZN11std$FS$core17StackTraceElementEE", %"record._ZN11std$FS$core11std$FS$core5ArrayIC_ZN11std$FS$core17StackTraceElementEE"* %0, i64 0, i32 0
  store i8 addrspace(1)* %4, i8 addrspace(1)** %atom.33641E.sroa.0.0..sroa_idx2
  %atom.33641E.sroa.4.0..sroa_idx5 = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIC_ZN11std$FS$core17StackTraceElementEE", %"record._ZN11std$FS$core11std$FS$core5ArrayIC_ZN11std$FS$core17StackTraceElementEE"* %0, i64 0, i32 1
  store i64 0, i64* %atom.33641E.sroa.4.0..sroa_idx5
  %atom.33641E.sroa.5.0..sroa_idx8 = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIC_ZN11std$FS$core17StackTraceElementEE", %"record._ZN11std$FS$core11std$FS$core5ArrayIC_ZN11std$FS$core17StackTraceElementEE"* %0, i64 0, i32 2
  store i64 %7, i64* %atom.33641E.sroa.5.0..sroa_idx8
  ret void
}

attributes #0 = { readonly "GCRoot" }

!llvm.module.flags = !{!9}

; CHECK:         !0 = !{!"R_ZN11std$FS$core5ArrayIlE"
; CHECK-NEXT:    !1 = !{!"R_ZN11std$FS$core5ArrayIR_ZN11std$FS$core6StringEE"}
; CHECK-NEXT:    !2 = !{!"A1_hE"}
; CHECK-NEXT:    !3 = !{!"R_ZN11std$FS$core6StringE"}
; CHECK-NEXT:    !4 = !{!"R_ZN11std$FS$core5ArrayIhE"}
; CHECK-NEXT:    !5 = !{i32 2, !"CJBC", i32 1}
; CHECK-NEXT:    !6 = distinct !{!"record._ZN11std$FS$core11std$FS$core5ArrayIlE"}
; CHECK-NEXT:    !7 = !{!"record._ZN11std$FS$core11std$FS$core5ArrayIlE"}
; CHECK-NEXT:    !8 = distinct !{!"record._ZN11std$FS$core11std$FS$core5ArrayIlE"}
; CHECK-NEXT:    !9 = !{!"record._ZN11std$FS$core6StringE"}
!0 = !{!"R_ZN11std$FS$core5ArrayIhE"}
!1 = !{!"A1_hE"}
!2 = !{!"R_ZN11std$FS$core5ArrayIlE"}
!3 = !{!"R_ZN11std$FS$core5ArrayIR_ZN11std$FS$core6StringEE"}
!4 = !{!"R_ZN11std$FS$core6StringE"}
!5 = !{!"record._ZN11std$FS$core6StringE"}
!6 = !{!"record._ZN11std$FS$core11std$FS$core5ArrayIhE"}
!7 = !{!"record._ZN11std$FS$core11std$FS$core5ArrayIlE"}
!8 = !{!"record._ZN11std$FS$core11std$FS$core5ArrayIR_ZN11std$FS$core6StringEE"}
!9 = !{i32 2, !"CJBC", i32 1}
