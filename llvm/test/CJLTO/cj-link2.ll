; RUN: llvm-as %s -o %t.bc
; RUN: llvm-as %p/Inputs/same-type1.ll -o %t1.bc
; RUN: llvm-as %p/Inputs/same-type2.ll -o %t2.bc
; RUN: llvm-link %t.bc %t1.bc %t2.bc -S | FileCheck %s

; CHECK:         %KlassInfo.0 = type { i32, i32, %BitMap*, i8*, i8**, i64*, i64*, i64*, i32, [0 x i8*] }
; CHECK-NEXT:    %BitMap = type { i32, [0 x i8] }
; CHECK-NEXT:    %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" = type { i8 addrspace(1)*, i64, i64 }
; CHECK-NEXT:    %KlassInfo.1 = type { i32, i32, %BitMap*, i8*, i8**, i64*, i64*, i64*, i32, [1 x i8*] }
; CHECK-NEXT:    %"record._ZN11std$FS$core6StringE" = type { i8 addrspace(1)*, i64 }
; CHECK-NEXT:    %"record._ZN13std$FS$random11std$FS$core6OptionIdE" = type { i1, double }
; CHECK-NEXT:    %ArrayLayout.UInt64 = type { %ArrayBase, [0 x i64] }
; CHECK-NEXT:    %ArrayBase = type { %ObjLayout.Object, i64 }
; CHECK-NEXT:    %ObjLayout.Object = type { %KlassInfo.0* }
; CHECK-NEXT:    %ArrayLayout.UInt8 = type { %ArrayBase, [0 x i8] }
; CHECK-NEXT:    %Unit.Type = type { i8 }
; CHECK-NEXT:    %"record._ZN11std$FS$core8Utf8ViewE" = type { %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" }
; CHECK-NEXT:    %T2_clE = type { i32, i64 }
; CHECK-NEXT:    %ArrayLayout.Char = type { %ArrayBase, [0 x i32] }
; CHECK-NEXT:    %"record._ZN17std$FS$collection11std$FS$core6OptionIcE" = type { i1, i32 }
; CHECK-NEXT:    %"ArrayLayout._ZN11std$FS$core6StringE" = type { %ArrayBase, [0 x %"record._ZN11std$FS$core6StringE"] }
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
; CHECK-NEXT:    @"_ZN11std$FS$core17EMPTY_UINT8_ARRAYE" = global %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" zeroinitializer, !GlobalVarType !3 #0
; CHECK-NEXT:    @"$const_string.15" = private unnamed_addr constant [4 x i8] c"add\00", align 1
; CHECK-NEXT:    @"$const_string.16" = private unnamed_addr constant [4 x i8] c"sub\00", align 1
; CHECK-NEXT:    @"$const_string.22" = private unnamed_addr constant [9 x i8] c"typecast\00", align 1
; CHECK-NEXT:    @UInt64.arrayKlass = weak_odr global %KlassInfo.0 { i32 2, i32 8, %BitMap* null, i8* bitcast (%KlassInfo.0* @array_uint64.primKlass to i8*), i8** null, i64* null, i64* null, i64* bitcast ([6 x i8]* @A1_mE.className to i64*), i32 0, [0 x i8*] zeroinitializer }
; CHECK-NEXT:    @A1_mE.className = weak_odr global [6 x i8] c"A1_mE\00", align 1
; CHECK-NEXT:    @array_uint64.primKlass = weak_odr global %KlassInfo.0 { i32 1, i32 8, %BitMap* null, i8* null, i8** null, i64* null, i64* null, i64* @array_uint64.uniqueAddr, i32 0, [0 x i8*] zeroinitializer }
; CHECK-NEXT:    @array_uint64.uniqueAddr = weak_odr global i64 0
; CHECK-NEXT:    @"$const_string.29" = private unnamed_addr constant [4 x i8] c"add\00", align 1
; CHECK-NEXT:    @"$const_string.30" = private unnamed_addr constant [4 x i8] c"mul\00", align 1
; CHECK-NEXT:    @"$const_string.33" = private unnamed_addr constant [11 x i8] c"iterator$0\00", align 1
; CHECK-NEXT:    @"$const_string.34" = private unnamed_addr constant [7 x i8] c"next$0\00", align 1
; CHECK-NEXT:    @"$const_string.35" = private unnamed_addr constant [11 x i8] c"$sizeget$0\00", align 1
; CHECK-NEXT:    @Char.arrayKlass = weak_odr global %KlassInfo.0 { i32 2, i32 4, %BitMap* null, i8* bitcast (%KlassInfo.0* @array_char.primKlass to i8*), i8** null, i64* null, i64* null, i64* bitcast ([6 x i8]* @A1_cE.className to i64*), i32 0, [0 x i8*] zeroinitializer }
; CHECK-NEXT:    @A1_cE.className = weak_odr global [6 x i8] c"A1_cE\00", align 1
; CHECK-NEXT:    @array_char.primKlass = weak_odr global %KlassInfo.0 { i32 1, i32 4, %BitMap* null, i8* null, i8** null, i64* null, i64* null, i64* @array_char.uniqueAddr, i32 0, [0 x i8*] zeroinitializer }
; CHECK-NEXT:    @array_char.uniqueAddr = weak_odr global i64 0
; CHECK-NEXT:    @"_ZN11std$FS$core25IndexOutOfBoundsExceptionE.objKlass" = external global %KlassInfo.0
; CHECK-NEXT:    @"_ZN11std$FS$core26NegativeArraySizeExceptionE.objKlass" = external global %KlassInfo.0
; CHECK-NEXT:    @"_ZN11std$FS$core6String5emptyE" = global %"record._ZN11std$FS$core6StringE" zeroinitializer, !GlobalVarType !4 #0
; CHECK-NEXT:    @"_ZN11std$FS$core6StringE.arrayKlass" = weak_odr global %KlassInfo.0 { i32 34, i32 16, %BitMap* null, i8* bitcast (%KlassInfo.0* @"record._ZN11std$FS$core6StringE.structKlass" to i8*), i8** null, i64* null, i64* null, i64* bitcast ([30 x i8]* @"A1_R_ZN11std$FS$core6StringEE.className" to i64*), i32 0, [0 x i8*] zeroinitializer } #0
; CHECK-NEXT:    @"A1_R_ZN11std$FS$core6StringEE.className" = weak_odr global [30 x i8] c"A1_R_ZN11std$FS$core6StringEE\00", align 1
; CHECK-NEXT:    @"record._ZN11std$FS$core6StringE.structKlass" = weak_odr global %KlassInfo.0 { i32 40, i32 16, %BitMap* inttoptr (i64 -9223372036854775807 to %BitMap*), i8* null, i8** null, i64* null, i64* null, i64* @"record._ZN11std$FS$core6StringE.uniqueAddr", i32 0, [0 x i8*] zeroinitializer } #0
; CHECK-NEXT:    @"record._ZN11std$FS$core6StringE.uniqueAddr" = weak_odr global i64 0
; CHECK-NEXT:    @"_ZN15std$$collection22$__STRING_LITERAL__$22E" = internal global %"record._ZN11std$FS$core6StringE" zeroinitializer
; CHECK-NEXT:    @"_ZN15std$$collection22$__STRING_LITERAL__$23E" = internal global %"record._ZN11std$FS$core6StringE" zeroinitializer
; CHECK-NEXT:    @"_ZN15std$$collection22$__STRING_LITERAL__$24E" = internal global %"record._ZN11std$FS$core6StringE" zeroinitializer
; CHECK-NEXT:    @"_ZN15std$$collection22$__STRING_LITERAL__$25E" = internal global %"record._ZN11std$FS$core6StringE" zeroinitializer
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

; CHECK-LABEL: @goo1(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[ENUMTMP50:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[CALLRET49:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[ENUMTMP40:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[CALLRET39:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[ENUMTMP34:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[CALLRET33:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[ENUMTMP29:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[CALLRET28:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[ENUMTMP23:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[CALLRET22:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[ENUMTMP19:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[CALLRET18:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[ENUMTMP13:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[CALLRET12:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[ENUMTMP5:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[CALLRET4:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[ENUMTMP3:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[CALLRET2:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[ENUMTMP:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[CALLRET:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[TMP0:%.*]] = alloca %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", align 8
; CHECK-NEXT:    [[ATOM_5655E:%.*]] = alloca %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", align 8
; CHECK-NEXT:    [[ENUM_VAL:%.*]] = alloca %"record._ZN13std$FS$random11std$FS$core6OptionIdE", align 8
; CHECK-NEXT:    [[ENUMTMP50_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[ENUMTMP50]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[ENUMTMP50_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[TMP1:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[CALLRET49]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull align 8 [[TMP1]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[ENUMTMP40_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[ENUMTMP40]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[ENUMTMP40_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[TMP2:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[CALLRET39]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull align 8 [[TMP2]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[ENUMTMP34_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[ENUMTMP34]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[ENUMTMP34_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[CALLRET33_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[CALLRET33]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[CALLRET33_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[ENUMTMP29_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[ENUMTMP29]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[ENUMTMP29_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[TMP3:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[CALLRET28]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull align 8 [[TMP3]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[ENUMTMP23_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[ENUMTMP23]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[ENUMTMP23_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[CALLRET22_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[CALLRET22]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[CALLRET22_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[ENUMTMP19_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[ENUMTMP19]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[ENUMTMP19_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[CALLRET18_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[CALLRET18]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[CALLRET18_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[ENUMTMP13_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[ENUMTMP13]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[ENUMTMP13_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[CALLRET12_0_SROA_CAST37:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[CALLRET12]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[CALLRET12_0_SROA_CAST37]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[ENUMTMP5_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[ENUMTMP5]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[ENUMTMP5_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[TMP4:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[CALLRET4]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull align 8 [[TMP4]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[ENUMTMP3_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[ENUMTMP3]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[ENUMTMP3_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[CALLRET2_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[CALLRET2]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[CALLRET2_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[ENUMTMP_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[ENUMTMP]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[ENUMTMP_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[CALLRET_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[CALLRET]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[CALLRET_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[DOT0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[TMP0]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[DOT0_SROA_CAST]], i8 0, i64 24, i1 false)
; CHECK-NEXT:    [[TMP5:%.*]] = bitcast %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[ATOM_5655E]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull align 8 [[TMP5]], i8 0, i64 24, i1 false)
; CHECK-NEXT:    [[TMP6:%.*]] = getelementptr inbounds i8, i8 addrspace(1)* [[THIS:%.*]], i64 56
; CHECK-NEXT:    [[TMP7:%.*]] = bitcast i8 addrspace(1)* [[TMP6]] to i64 addrspace(1)*
; CHECK-NEXT:    call void @llvm.cj.gcwrite.i64.i64(i64 [[SEED:%.*]], i8 addrspace(1)* [[THIS]], i64 addrspace(1)* [[TMP7]])
; CHECK-NEXT:    [[TMP8:%.*]] = getelementptr inbounds %"record._ZN13std$FS$random11std$FS$core6OptionIdE", %"record._ZN13std$FS$random11std$FS$core6OptionIdE"* [[ENUM_VAL]], i64 0, i32 0
; CHECK-NEXT:    store i1 true, i1* [[TMP8]], align 1
; CHECK-NEXT:    [[TMP9:%.*]] = getelementptr inbounds %"record._ZN13std$FS$random11std$FS$core6OptionIdE", %"record._ZN13std$FS$random11std$FS$core6OptionIdE"* [[ENUM_VAL]], i64 0, i32 1
; CHECK-NEXT:    store double 0.000000e+00, double* [[TMP9]], align 8
; CHECK-NEXT:    [[TMP10:%.*]] = getelementptr inbounds i8, i8 addrspace(1)* [[THIS]], i64 40
; CHECK-NEXT:    [[TMP11:%.*]] = bitcast %"record._ZN13std$FS$random11std$FS$core6OptionIdE"* [[ENUM_VAL]] to i8*
; CHECK-NEXT:    call void @llvm.cj.gcwrite.struct.p0i8.i64(i8 addrspace(1)* [[THIS]], i8 addrspace(1)* [[TMP10]], i8* nonnull [[TMP11]], i64 16)
; CHECK-NEXT:    call void @llvm.memcpy.p0i8.p0i8.i64(i8* noundef nonnull align 8 dereferenceable(24) [[TMP5]], i8* noundef nonnull align 8 dereferenceable(24) [[DOT0_SROA_CAST]], i64 24, i1 false)
; CHECK-NEXT:    [[TMP12:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[ATOM_5655E]], i64 0, i32 1
; CHECK-NEXT:    store i64 0, i64* [[TMP12]], align 4
; CHECK-NEXT:    [[TMP13:%.*]] = call noalias i8 addrspace(1)* @CJ_MCC_NewArray64Stub(i64 312, i8* bitcast (%KlassInfo.0* @UInt64.arrayKlass to i8*))
; CHECK-NEXT:    [[TMP14:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[ATOM_5655E]], i64 0, i32 0
; CHECK-NEXT:    store i8 addrspace(1)* [[TMP13]], i8 addrspace(1)** [[TMP14]], align 8
; CHECK-NEXT:    [[TMP15:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[ATOM_5655E]], i64 0, i32 2
; CHECK-NEXT:    store i64 312, i64* [[TMP15]], align 4
; CHECK-NEXT:    [[TMP16:%.*]] = getelementptr inbounds i8, i8 addrspace(1)* [[THIS]], i64 8
; CHECK-NEXT:    call void @llvm.cj.gcwrite.struct.p0i8.i64(i8 addrspace(1)* [[THIS]], i8 addrspace(1)* [[TMP16]], i8* nonnull [[TMP5]], i64 24)
; CHECK-NEXT:    [[TMP17:%.*]] = getelementptr inbounds i8, i8 addrspace(1)* [[THIS]], i64 24
; CHECK-NEXT:    [[TMP18:%.*]] = bitcast i8 addrspace(1)* [[TMP17]] to i64 addrspace(1)*
; CHECK-NEXT:    [[TMP19:%.*]] = load i64, i64 addrspace(1)* [[TMP18]], align 4
; CHECK-NEXT:    [[ICMPUGE:%.*]] = icmp eq i64 [[TMP19]], 0
; CHECK-NEXT:    br i1 [[ICMPUGE]], label [[IF_THEN7294E:%.*]], label [[IF_ELSE7294E:%.*]]
; CHECK:       if.then7294E:
; CHECK-NEXT:    [[TMP20:%.*]] = call noalias i8 addrspace(1)* @CJ_MCC_NewObjectStub(i8* bitcast (%KlassInfo.0* @"_ZN11std$FS$core25IndexOutOfBoundsExceptionE.objKlass" to i8*), i32 56)
; CHECK-NEXT:    call void @"_ZN11std$FS$core25IndexOutOfBoundsException4initEv"(i8 addrspace(1)* [[TMP20]])
; CHECK-NEXT:    call void @CJ_MCC_ThrowException(i8 addrspace(1)* [[TMP20]])
; CHECK-NEXT:    unreachable
; CHECK:       if.else7294E:
; CHECK-NEXT:    [[TMP21:%.*]] = load i64, i64 addrspace(1)* [[TMP7]], align 4
; CHECK-NEXT:    [[TMP22:%.*]] = bitcast i8 addrspace(1)* [[TMP16]] to i8 addrspace(1)* addrspace(1)*
; CHECK-NEXT:    [[TMP23:%.*]] = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* [[TMP22]], align 8
; CHECK-NEXT:    [[TMP24:%.*]] = getelementptr inbounds i8, i8 addrspace(1)* [[THIS]], i64 16
; CHECK-NEXT:    [[TMP25:%.*]] = bitcast i8 addrspace(1)* [[TMP24]] to i64 addrspace(1)*
; CHECK-NEXT:    [[TMP26:%.*]] = load i64, i64 addrspace(1)* [[TMP25]], align 4
; CHECK-NEXT:    [[TMP27:%.*]] = bitcast i8 addrspace(1)* [[TMP23]] to [[ARRAYLAYOUT_UINT64:%.*]] addrspace(1)*
; CHECK-NEXT:    [[ARR_IDX_SET_GEP:%.*]] = getelementptr inbounds [[ARRAYLAYOUT_UINT64]], [[ARRAYLAYOUT_UINT64]] addrspace(1)* [[TMP27]], i64 0, i32 1, i64 [[TMP26]]
; CHECK-NEXT:    call void @llvm.cj.gcwrite.i64.i64(i64 [[TMP21]], i8 addrspace(1)* [[TMP23]], i64 addrspace(1)* [[ARR_IDX_SET_GEP]])
; CHECK-NEXT:    [[TMP28:%.*]] = getelementptr inbounds i8, i8 addrspace(1)* [[THIS]], i64 32
; CHECK-NEXT:    [[TMP29:%.*]] = bitcast i8 addrspace(1)* [[TMP28]] to i64 addrspace(1)*
; CHECK-NEXT:    call void @llvm.cj.gcwrite.i64.i64(i64 1, i8 addrspace(1)* [[THIS]], i64 addrspace(1)* [[TMP29]])
; CHECK-NEXT:    [[TMP30:%.*]] = load i64, i64 addrspace(1)* [[TMP29]], align 4
; CHECK-NEXT:    [[ICMPSLT35:%.*]] = icmp slt i64 [[TMP30]], 312
; CHECK-NEXT:    br i1 [[ICMPSLT35]], label [[WHILE_BODY4736E:%.*]], label [[BLOCK_END4688E:%.*]]
; CHECK:       while.body4736E:
; CHECK-NEXT:    [[TMP31:%.*]] = phi i64 [ [[TMP49:%.*]], [[NORMAL0E48:%.*]] ], [ [[TMP30]], [[IF_ELSE7294E]] ]
; CHECK-NEXT:    [[TMP32:%.*]] = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 [[TMP31]], i64 -1)
; CHECK-NEXT:    [[DOTFCA_0_EXTRACT:%.*]] = extractvalue { i64, i1 } [[TMP32]], 0
; CHECK-NEXT:    [[DOTFCA_1_EXTRACT:%.*]] = extractvalue { i64, i1 } [[TMP32]], 1
; CHECK-NEXT:    br i1 [[DOTFCA_1_EXTRACT]], label [[OVERFLOW0E:%.*]], label [[NORMAL0E:%.*]], !prof [[PROF10:![0-9]+]]
; CHECK:       normal0E:
; CHECK-NEXT:    [[TMP33:%.*]] = load i64, i64 addrspace(1)* [[TMP18]], align 4
; CHECK-NEXT:    [[ICMPUGE7_NOT:%.*]] = icmp ult i64 [[DOTFCA_0_EXTRACT]], [[TMP33]]
; CHECK-NEXT:    br i1 [[ICMPUGE7_NOT]], label [[IF_ELSE7328E:%.*]], label [[IF_THEN7328E:%.*]]
; CHECK:       overflow0E:
; CHECK-NEXT:    call void @"_ZN11std$FS$core6String23createStringFromLiteralE"(%"record._ZN11std$FS$core6StringE"* noalias nonnull sret(%"record._ZN11std$FS$core6StringE") [[CALLRET4]], i8* getelementptr inbounds ([4 x i8], [4 x i8]* @"$const_string.16", i64 0, i64 0), i64 3)
; CHECK-NEXT:    [[TMP34:%.*]] = addrspacecast %"record._ZN11std$FS$core6StringE"* [[CALLRET4]] to %"record._ZN11std$FS$core6StringE" addrspace(1)*
; CHECK-NEXT:    [[TMP35:%.*]] = call i8 addrspace(1)* @"rt$CreateOverflowException_msg"(i8 addrspace(1)* null, %"record._ZN11std$FS$core6StringE" addrspace(1)* [[TMP34]])
; CHECK-NEXT:    call void @CJ_MCC_ThrowException(i8 addrspace(1)* [[TMP35]])
; CHECK-NEXT:    unreachable
; CHECK:       if.then7328E:
; CHECK-NEXT:    [[TMP36:%.*]] = call noalias i8 addrspace(1)* @CJ_MCC_NewObjectStub(i8* bitcast (%KlassInfo.0* @"_ZN11std$FS$core25IndexOutOfBoundsExceptionE.objKlass" to i8*), i32 56)
; CHECK-NEXT:    call void @"_ZN11std$FS$core25IndexOutOfBoundsException4initEv"(i8 addrspace(1)* [[TMP36]])
; CHECK-NEXT:    call void @CJ_MCC_ThrowException(i8 addrspace(1)* [[TMP36]])
; CHECK-NEXT:    unreachable
; CHECK:       if.else7328E:
; CHECK-NEXT:    [[TMP37:%.*]] = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* [[TMP22]], align 8
; CHECK-NEXT:    [[TMP38:%.*]] = load i64, i64 addrspace(1)* [[TMP25]], align 4
; CHECK-NEXT:    [[TMP39:%.*]] = bitcast i8 addrspace(1)* [[TMP37]] to [[ARRAYLAYOUT_UINT64]] addrspace(1)*
; CHECK-NEXT:    [[I2UI_LT:%.*]] = icmp slt i64 [[TMP31]], 0
; CHECK-NEXT:    br i1 [[I2UI_LT]], label [[IF_OVF_LT0E27:%.*]], label [[ELSE_OVF_GT0E31:%.*]]
; CHECK:       if.ovf.lt0E27:
; CHECK-NEXT:    call void @"_ZN11std$FS$core6String23createStringFromLiteralE"(%"record._ZN11std$FS$core6StringE"* noalias nonnull sret(%"record._ZN11std$FS$core6StringE") [[CALLRET28]], i8* getelementptr inbounds ([9 x i8], [9 x i8]* @"$const_string.22", i64 0, i64 0), i64 8)
; CHECK-NEXT:    [[TMP40:%.*]] = addrspacecast %"record._ZN11std$FS$core6StringE"* [[CALLRET28]] to %"record._ZN11std$FS$core6StringE" addrspace(1)*
; CHECK-NEXT:    [[TMP41:%.*]] = call i8 addrspace(1)* @"rt$CreateOverflowException_msg"(i8 addrspace(1)* null, %"record._ZN11std$FS$core6StringE" addrspace(1)* [[TMP40]])
; CHECK-NEXT:    call void @CJ_MCC_ThrowException(i8 addrspace(1)* [[TMP41]])
; CHECK-NEXT:    unreachable
; CHECK:       else.ovf.gt0E31:
; CHECK-NEXT:    [[ADD:%.*]] = add i64 [[TMP38]], [[DOTFCA_0_EXTRACT]]
; CHECK-NEXT:    [[ARR_IDX_GET_GEP:%.*]] = getelementptr inbounds [[ARRAYLAYOUT_UINT64]], [[ARRAYLAYOUT_UINT64]] addrspace(1)* [[TMP39]], i64 0, i32 1, i64 [[ADD]]
; CHECK-NEXT:    [[TMP42:%.*]] = load i64, i64 addrspace(1)* [[ARR_IDX_GET_GEP]], align 4
; CHECK-NEXT:    [[LSHR:%.*]] = lshr i64 [[TMP42]], 62
; CHECK-NEXT:    [[XOR:%.*]] = xor i64 [[LSHR]], [[TMP42]]
; CHECK-NEXT:    [[MUL:%.*]] = mul i64 [[XOR]], 6364136223846793005
; CHECK-NEXT:    [[TMP43:%.*]] = call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 [[MUL]], i64 [[TMP31]])
; CHECK-NEXT:    [[DOTFCA_0_EXTRACT11:%.*]] = extractvalue { i64, i1 } [[TMP43]], 0
; CHECK-NEXT:    [[DOTFCA_1_EXTRACT12:%.*]] = extractvalue { i64, i1 } [[TMP43]], 1
; CHECK-NEXT:    br i1 [[DOTFCA_1_EXTRACT12]], label [[OVERFLOW0E37:%.*]], label [[NORMAL0E38:%.*]], !prof [[PROF10]]
; CHECK:       normal0E38:
; CHECK-NEXT:    [[ICMPUGE42_NOT:%.*]] = icmp ult i64 [[TMP31]], [[TMP33]]
; CHECK-NEXT:    br i1 [[ICMPUGE42_NOT]], label [[IF_ELSE7402E:%.*]], label [[IF_THEN7402E:%.*]]
; CHECK:       overflow0E37:
; CHECK-NEXT:    call void @"_ZN11std$FS$core6String23createStringFromLiteralE"(%"record._ZN11std$FS$core6StringE"* noalias nonnull sret(%"record._ZN11std$FS$core6StringE") [[CALLRET39]], i8* getelementptr inbounds ([4 x i8], [4 x i8]* @"$const_string.15", i64 0, i64 0), i64 3)
; CHECK-NEXT:    [[TMP44:%.*]] = addrspacecast %"record._ZN11std$FS$core6StringE"* [[CALLRET39]] to %"record._ZN11std$FS$core6StringE" addrspace(1)*
; CHECK-NEXT:    [[TMP45:%.*]] = call i8 addrspace(1)* @"rt$CreateOverflowException_msg"(i8 addrspace(1)* null, %"record._ZN11std$FS$core6StringE" addrspace(1)* [[TMP44]])
; CHECK-NEXT:    call void @CJ_MCC_ThrowException(i8 addrspace(1)* [[TMP45]])
; CHECK-NEXT:    unreachable
; CHECK:       if.then7402E:
; CHECK-NEXT:    [[TMP46:%.*]] = call noalias i8 addrspace(1)* @CJ_MCC_NewObjectStub(i8* bitcast (%KlassInfo.0* @"_ZN11std$FS$core25IndexOutOfBoundsExceptionE.objKlass" to i8*), i32 56)
; CHECK-NEXT:    call void @"_ZN11std$FS$core25IndexOutOfBoundsException4initEv"(i8 addrspace(1)* [[TMP46]])
; CHECK-NEXT:    call void @CJ_MCC_ThrowException(i8 addrspace(1)* [[TMP46]])
; CHECK-NEXT:    unreachable
; CHECK:       if.else7402E:
; CHECK-NEXT:    [[ADD43:%.*]] = add i64 [[TMP38]], [[TMP31]]
; CHECK-NEXT:    [[ARR_IDX_SET_GEP44:%.*]] = getelementptr inbounds [[ARRAYLAYOUT_UINT64]], [[ARRAYLAYOUT_UINT64]] addrspace(1)* [[TMP39]], i64 0, i32 1, i64 [[ADD43]]
; CHECK-NEXT:    call void @llvm.cj.gcwrite.i64.i64(i64 [[DOTFCA_0_EXTRACT11]], i8 addrspace(1)* [[TMP37]], i64 addrspace(1)* [[ARR_IDX_SET_GEP44]])
; CHECK-NEXT:    [[TMP47:%.*]] = load i64, i64 addrspace(1)* [[TMP29]], align 4
; CHECK-NEXT:    [[TMP48:%.*]] = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 [[TMP47]], i64 1)
; CHECK-NEXT:    [[DOTFCA_1_EXTRACT16:%.*]] = extractvalue { i64, i1 } [[TMP48]], 1
; CHECK-NEXT:    br i1 [[DOTFCA_1_EXTRACT16]], label [[OVERFLOW0E47:%.*]], label [[NORMAL0E48]], !prof [[PROF10]]
; CHECK:       normal0E48:
; CHECK-NEXT:    [[DOTFCA_0_EXTRACT15:%.*]] = extractvalue { i64, i1 } [[TMP48]], 0
; CHECK-NEXT:    call void @llvm.cj.gcwrite.i64.i64(i64 [[DOTFCA_0_EXTRACT15]], i8 addrspace(1)* [[THIS]], i64 addrspace(1)* [[TMP29]])
; CHECK-NEXT:    [[TMP49]] = load i64, i64 addrspace(1)* [[TMP29]], align 4
; CHECK-NEXT:    [[ICMPSLT:%.*]] = icmp slt i64 [[TMP49]], 312
; CHECK-NEXT:    br i1 [[ICMPSLT]], label [[WHILE_BODY4736E]], label [[BLOCK_END4688E]]
; CHECK:       overflow0E47:
; CHECK-NEXT:    call void @"_ZN11std$FS$core6String23createStringFromLiteralE"(%"record._ZN11std$FS$core6StringE"* noalias nonnull sret(%"record._ZN11std$FS$core6StringE") [[CALLRET49]], i8* getelementptr inbounds ([4 x i8], [4 x i8]* @"$const_string.15", i64 0, i64 0), i64 3)
; CHECK-NEXT:    [[TMP50:%.*]] = addrspacecast %"record._ZN11std$FS$core6StringE"* [[CALLRET49]] to %"record._ZN11std$FS$core6StringE" addrspace(1)*
; CHECK-NEXT:    [[TMP51:%.*]] = call i8 addrspace(1)* @"rt$CreateOverflowException_msg"(i8 addrspace(1)* null, %"record._ZN11std$FS$core6StringE" addrspace(1)* [[TMP50]])
; CHECK-NEXT:    call void @CJ_MCC_ThrowException(i8 addrspace(1)* [[TMP51]])
; CHECK-NEXT:    unreachable
; CHECK:       block.end4688E:
; CHECK-NEXT:    ret void
;

; CHECK-LABEL: @goo2(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[ENUMTMP:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[CALLRET:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[ENUMTMP_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[ENUMTMP]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[ENUMTMP_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[CALLRET_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[CALLRET]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[CALLRET_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[TMP1:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)* [[ARRAY:%.*]], i64 0, i32 2
; CHECK-NEXT:    [[TMP2:%.*]] = load i64, i64 addrspace(1)* [[TMP1]], align 4
; CHECK-NEXT:    [[ICMPSLT5:%.*]] = icmp sgt i64 [[TMP2]], 0
; CHECK-NEXT:    br i1 [[ICMPSLT5]], label [[WHILE_BODY2474E_LR_PH:%.*]], label [[BLOCK_END2448E:%.*]]
; CHECK:       while.body2474E.lr.ph:
; CHECK-NEXT:    [[TMP3:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)* [[ARRAY]], i64 0, i32 0
; CHECK-NEXT:    [[TMP4:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)* [[ARRAY]], i64 0, i32 1
; CHECK-NEXT:    br label [[WHILE_BODY2474E:%.*]]
; CHECK:       while.body2474E:
; CHECK-NEXT:    [[ATOM_5600E_06:%.*]] = phi i64 [ 0, [[WHILE_BODY2474E_LR_PH]] ], [ [[TMP16:%.*]], [[WHILE_BODY2474E]] ]
; CHECK-NEXT:    [[TMP5:%.*]] = call i8* @CJ_MCC_GetObjClass(i8 addrspace(1)* [[THIS:%.*]])
; CHECK-NEXT:    [[TMP6:%.*]] = getelementptr i8, i8* [[TMP5]], i64 24
; CHECK-NEXT:    [[TMP7:%.*]] = bitcast i8* [[TMP6]] to i8***
; CHECK-NEXT:    [[TMP8:%.*]] = load i8**, i8*** [[TMP7]], align 8
; CHECK-NEXT:    [[TMP9:%.*]] = getelementptr i8*, i8** [[TMP8]], i64 5
; CHECK-NEXT:    [[TMP10:%.*]] = bitcast i8** [[TMP9]] to i8 (i8 addrspace(1)*)**
; CHECK-NEXT:    [[TMP11:%.*]] = load i8 (i8 addrspace(1)*)*, i8 (i8 addrspace(1)*)** [[TMP10]], align 8
; CHECK-NEXT:    [[TMP12:%.*]] = call i8 [[TMP11]](i8 addrspace(1)* [[THIS]])
; CHECK-NEXT:    [[TMP13:%.*]] = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* [[TMP3]], align 8
; CHECK-NEXT:    [[TMP14:%.*]] = load i64, i64 addrspace(1)* [[TMP4]], align 4
; CHECK-NEXT:    [[ADD:%.*]] = add i64 [[TMP14]], [[ATOM_5600E_06]]
; CHECK-NEXT:    [[TMP15:%.*]] = bitcast i8 addrspace(1)* [[TMP13]] to [[ARRAYLAYOUT_UINT8:%.*]] addrspace(1)*
; CHECK-NEXT:    [[ARR_IDX_SET_GEP:%.*]] = getelementptr inbounds [[ARRAYLAYOUT_UINT8]], [[ARRAYLAYOUT_UINT8]] addrspace(1)* [[TMP15]], i64 0, i32 1, i64 [[ADD]]
; CHECK-NEXT:    call void @llvm.cj.gcwrite.i8.i8(i8 [[TMP12]], i8 addrspace(1)* [[TMP13]], i8 addrspace(1)* [[ARR_IDX_SET_GEP]])
; CHECK-NEXT:    [[TMP16]] = add nuw nsw i64 [[ATOM_5600E_06]], 1
; CHECK-NEXT:    [[TMP17:%.*]] = load i64, i64 addrspace(1)* [[TMP1]], align 4
; CHECK-NEXT:    [[ICMPSLT:%.*]] = icmp slt i64 [[TMP16]], [[TMP17]]
; CHECK-NEXT:    br i1 [[ICMPSLT]], label [[WHILE_BODY2474E]], label [[BLOCK_END2448E]]
; CHECK:       block.end2448E:
; CHECK-NEXT:    [[TMP18:%.*]] = bitcast %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[TMP0:%.*]] to i8*
; CHECK-NEXT:    [[TMP19:%.*]] = bitcast %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)* [[ARRAY]] to i8 addrspace(1)*
; CHECK-NEXT:    call void @llvm.memcpy.p0i8.p1i8.i64(i8* noundef nonnull align 8 dereferenceable(24) [[TMP18]], i8 addrspace(1)* noundef align 8 dereferenceable(24) [[TMP19]], i64 24, i1 false)
; CHECK-NEXT:    ret void
;

; CHECK-LABEL: @hoo1(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[CALLRET_I:%.*]] = alloca [[UNIT_TYPE:%.*]], align 8
; CHECK-NEXT:    [[CALLRET6:%.*]] = alloca [[UNIT_TYPE]], align 8
; CHECK-NEXT:    [[ENUMTMP_SROA_0:%.*]] = alloca %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", align 8
; CHECK-NEXT:    [[STRDATA:%.*]] = alloca %"record._ZN11std$FS$core8Utf8ViewE", align 8
; CHECK-NEXT:    [[CALLRET1:%.*]] = alloca %"record._ZN11std$FS$core8Utf8ViewE", align 8
; CHECK-NEXT:    [[ENUMTMP_SROA_0_0_SROA_CAST8:%.*]] = bitcast %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[ENUMTMP_SROA_0]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[ENUMTMP_SROA_0_0_SROA_CAST8]], i8 0, i64 24, i1 false)
; CHECK-NEXT:    [[TMP0:%.*]] = bitcast %"record._ZN11std$FS$core8Utf8ViewE"* [[STRDATA]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull align 8 [[TMP0]], i8 0, i64 24, i1 false)
; CHECK-NEXT:    [[TMP1:%.*]] = bitcast %"record._ZN11std$FS$core8Utf8ViewE"* [[CALLRET1]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull align 8 [[TMP1]], i8 0, i64 24, i1 false)
; CHECK-NEXT:    call void @"_ZN17std$FS$collection13StringBuilder16checkRangeInsertEl"(%Unit.Type* noalias sret([[UNIT_TYPE]]) poison, i8 addrspace(1)* [[THIS:%.*]], i64 [[INDEX:%.*]])
; CHECK-NEXT:    call void @"_ZN11std$FS$core6String12$utf8ViewgetEv"(%"record._ZN11std$FS$core8Utf8ViewE"* noalias nonnull sret(%"record._ZN11std$FS$core8Utf8ViewE") [[CALLRET1]], i8 addrspace(1)* %"str$BP", %"record._ZN11std$FS$core6StringE" addrspace(1)* [[STR:%.*]])
; CHECK-NEXT:    call void @llvm.memcpy.p0i8.p0i8.i64(i8* noundef nonnull align 8 dereferenceable(24) [[TMP0]], i8* noundef nonnull align 8 dereferenceable(24) [[TMP1]], i64 24, i1 false)
; CHECK-NEXT:    [[TMP2:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core8Utf8ViewE", %"record._ZN11std$FS$core8Utf8ViewE"* [[STRDATA]], i64 0, i32 0, i32 2
; CHECK-NEXT:    [[TMP3:%.*]] = load i64, i64* [[TMP2]], align 4
; CHECK-NEXT:    call fastcc void @"_ZN17std$FS$collection13StringBuilder7reserveEl"(i8 addrspace(1)* [[THIS]], i64 [[TMP3]])
; CHECK-NEXT:    [[ICMPEQ:%.*]] = icmp eq i64 [[INDEX]], 0
; CHECK-NEXT:    br i1 [[ICMPEQ]], label [[IF_END16502E:%.*]], label [[IF_ELSE16502E:%.*]]
; CHECK:       if.else16502E:
; CHECK-NEXT:    [[TMP4:%.*]] = getelementptr inbounds i8, i8 addrspace(1)* [[THIS]], i64 32
; CHECK-NEXT:    [[TMP5:%.*]] = bitcast i8 addrspace(1)* [[TMP4]] to i64 addrspace(1)*
; CHECK-NEXT:    [[TMP6:%.*]] = load i64, i64 addrspace(1)* [[TMP5]], align 4
; CHECK-NEXT:    [[ICMPEQ3:%.*]] = icmp eq i64 [[TMP6]], [[INDEX]]
; CHECK-NEXT:    br i1 [[ICMPEQ3]], label [[IF_THEN16501E:%.*]], label [[IF_ELSE16501E:%.*]]
; CHECK:       if.then16501E:
; CHECK-NEXT:    [[TMP7:%.*]] = getelementptr inbounds i8, i8 addrspace(1)* [[THIS]], i64 40
; CHECK-NEXT:    [[TMP8:%.*]] = bitcast i8 addrspace(1)* [[TMP7]] to i64 addrspace(1)*
; CHECK-NEXT:    [[TMP9:%.*]] = load i64, i64 addrspace(1)* [[TMP8]], align 4
; CHECK-NEXT:    br label [[IF_END16502E]]
; CHECK:       if.else16501E:
; CHECK-NEXT:    [[SMAX_I:%.*]] = call i64 @llvm.smax.i64(i64 [[INDEX]], i64 0)
; CHECK-NEXT:    [[EXITCOND7_NOT_I:%.*]] = icmp slt i64 [[INDEX]], 1
; CHECK-NEXT:    br i1 [[EXITCOND7_NOT_I]], label [[IF_END16502E]], label [[WHILE_BODY325E_LR_PH_I:%.*]]
; CHECK:       while.body325E.lr.ph.i:
; CHECK-NEXT:    [[TMP10:%.*]] = getelementptr inbounds i8, i8 addrspace(1)* [[THIS]], i64 8
; CHECK-NEXT:    [[TMP11:%.*]] = bitcast i8 addrspace(1)* [[TMP10]] to %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)*
; CHECK-NEXT:    br label [[WHILE_BODY325E_I:%.*]]
; CHECK:       while.body325E.i:
; CHECK-NEXT:    [[ATOM_17274E_010_I:%.*]] = phi i64 [ 0, [[WHILE_BODY325E_LR_PH_I]] ], [ [[ADD_I:%.*]], [[WHILE_BODY325E_I]] ]
; CHECK-NEXT:    [[ATOM_17272E_09_I:%.*]] = phi i64 [ 0, [[WHILE_BODY325E_LR_PH_I]] ], [ [[ADD1_I:%.*]], [[WHILE_BODY325E_I]] ]
; CHECK-NEXT:    [[ATOM_17268E_08_I:%.*]] = phi i64 [ 0, [[WHILE_BODY325E_LR_PH_I]] ], [ [[SPEC_SELECT_I:%.*]], [[WHILE_BODY325E_I]] ]
; CHECK-NEXT:    [[TMP12:%.*]] = call i64 @"_ZN11std$FS$core6Extend4Char8utf8SizeER_ZN11std$FS$core5ArrayIhEl"(i8 addrspace(1)* [[THIS]], %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)* [[TMP11]], i64 [[ATOM_17272E_09_I]]), !noalias !11
; CHECK-NEXT:    [[ADD_I]] = add nuw nsw i64 [[ATOM_17274E_010_I]], 1
; CHECK-NEXT:    [[ADD1_I]] = add i64 [[TMP12]], [[ATOM_17272E_09_I]]
; CHECK-NEXT:    [[ICMPEQ2_I:%.*]] = icmp eq i64 [[ADD_I]], [[INDEX]]
; CHECK-NEXT:    [[SPEC_SELECT_I]] = select i1 [[ICMPEQ2_I]], i64 [[ADD1_I]], i64 [[ATOM_17268E_08_I]]
; CHECK-NEXT:    [[EXITCOND_NOT_I:%.*]] = icmp eq i64 [[ADD_I]], [[SMAX_I]]
; CHECK-NEXT:    br i1 [[EXITCOND_NOT_I]], label [[IF_END16502E]], label [[WHILE_BODY325E_I]]
; CHECK:       if.end16502E:
; CHECK-NEXT:    [[ATOM_17381E_0:%.*]] = phi i64 [ [[TMP9]], [[IF_THEN16501E]] ], [ 0, [[ENTRY:%.*]] ], [ 0, [[IF_ELSE16501E]] ], [ [[SPEC_SELECT_I]], [[WHILE_BODY325E_I]] ]
; CHECK-NEXT:    [[TMP13:%.*]] = getelementptr inbounds i8, i8 addrspace(1)* [[THIS]], i64 40
; CHECK-NEXT:    [[TMP14:%.*]] = bitcast i8 addrspace(1)* [[TMP13]] to i64 addrspace(1)*
; CHECK-NEXT:    [[TMP15:%.*]] = load i64, i64 addrspace(1)* [[TMP14]], align 4
; CHECK-NEXT:    [[ICMPNE_NOT:%.*]] = icmp eq i64 [[TMP15]], [[ATOM_17381E_0]]
; CHECK-NEXT:    br i1 [[ICMPNE_NOT]], label [[IF_END16525E:%.*]], label [[IF_THEN16525E:%.*]]
; CHECK:       if.then16525E:
; CHECK-NEXT:    [[TMP16:%.*]] = getelementptr inbounds i8, i8 addrspace(1)* [[THIS]], i64 8
; CHECK-NEXT:    [[TMP17:%.*]] = bitcast i8 addrspace(1)* [[TMP16]] to %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)*
; CHECK-NEXT:    [[ADD:%.*]] = add i64 [[ATOM_17381E_0]], [[TMP3]]
; CHECK-NEXT:    [[SUB:%.*]] = sub i64 [[TMP15]], [[ATOM_17381E_0]]
; CHECK-NEXT:    call fastcc void @"_ZN17std$FS$collection11std$FS$core5ArrayIh6copyToER_ZN11std$FS$core5ArrayIhElll"(%Unit.Type* noalias nonnull sret([[UNIT_TYPE]]) [[CALLRET6]], i8 addrspace(1)* [[THIS]], %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)* [[TMP17]], i8 addrspace(1)* [[THIS]], %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)* [[TMP17]], i64 [[ATOM_17381E_0]], i64 [[ADD]], i64 [[SUB]])
; CHECK-NEXT:    br label [[IF_END16525E]]
; CHECK:       if.end16525E:
; CHECK-NEXT:    [[TMP18:%.*]] = getelementptr inbounds i8, i8 addrspace(1)* [[THIS]], i64 8
; CHECK-NEXT:    [[TMP19:%.*]] = bitcast i8 addrspace(1)* [[TMP18]] to %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)*
; CHECK-NEXT:    [[TMP20:%.*]] = addrspacecast %"record._ZN11std$FS$core8Utf8ViewE"* [[STRDATA]] to %"record._ZN11std$FS$core8Utf8ViewE" addrspace(1)*
; CHECK-NEXT:    [[TMP21:%.*]] = getelementptr inbounds [[UNIT_TYPE]], %Unit.Type* [[CALLRET_I]], i64 0, i32 0
; CHECK-NEXT:    call void @llvm.lifetime.start.p0i8(i64 1, i8* nonnull [[TMP21]])
; CHECK-NEXT:    [[TMP22:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core8Utf8ViewE", %"record._ZN11std$FS$core8Utf8ViewE" addrspace(1)* [[TMP20]], i64 0, i32 0
; CHECK-NEXT:    [[TMP23:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core8Utf8ViewE", %"record._ZN11std$FS$core8Utf8ViewE" addrspace(1)* [[TMP20]], i64 0, i32 0, i32 2
; CHECK-NEXT:    [[TMP24:%.*]] = addrspacecast i64 addrspace(1)* [[TMP23]] to i64*
; CHECK-NEXT:    [[TMP25:%.*]] = load i64, i64* [[TMP24]], align 4
; CHECK-NEXT:    call fastcc void @"_ZN17std$FS$collection11std$FS$core5ArrayIh6copyToER_ZN11std$FS$core5ArrayIhElll"(%Unit.Type* noalias nonnull sret([[UNIT_TYPE]]) [[CALLRET_I]], i8 addrspace(1)* null, %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)* [[TMP22]], i8 addrspace(1)* [[THIS]], %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)* [[TMP19]], i64 0, i64 [[ATOM_17381E_0]], i64 [[TMP25]])
; CHECK-NEXT:    call void @llvm.lifetime.end.p0i8(i64 1, i8* nonnull [[TMP21]])
; CHECK-NEXT:    [[TMP26:%.*]] = load i64, i64 addrspace(1)* [[TMP14]], align 4
; CHECK-NEXT:    [[ADD7:%.*]] = add i64 [[TMP26]], [[TMP3]]
; CHECK-NEXT:    call void @llvm.cj.gcwrite.i64.i64(i64 [[ADD7]], i8 addrspace(1)* [[THIS]], i64 addrspace(1)* [[TMP14]])
; CHECK-NEXT:    [[TMP27:%.*]] = getelementptr inbounds i8, i8 addrspace(1)* [[THIS]], i64 32
; CHECK-NEXT:    [[TMP28:%.*]] = bitcast i8 addrspace(1)* [[TMP27]] to i64 addrspace(1)*
; CHECK-NEXT:    [[TMP29:%.*]] = load i64, i64 addrspace(1)* [[TMP28]], align 4
; CHECK-NEXT:    [[TMP30:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core6StringE", %"record._ZN11std$FS$core6StringE" addrspace(1)* [[STR]], i64 0, i32 1
; CHECK-NEXT:    [[TMP31:%.*]] = load i64, i64 addrspace(1)* [[TMP30]], align 4
; CHECK-NEXT:    [[ADD8:%.*]] = add i64 [[TMP31]], [[TMP29]]
; CHECK-NEXT:    call void @llvm.cj.gcwrite.i64.i64(i64 [[ADD8]], i8 addrspace(1)* [[THIS]], i64 addrspace(1)* [[TMP28]])
; CHECK-NEXT:    ret i8 addrspace(1)* [[THIS]]
;

; CHECK-LABEL: @hoo2(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[ENUMTMP7:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[CALLRET6:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[ENUMTMP:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[CALLRET1:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[CALLRET:%.*]] = alloca [[T2_CLE:%.*]], align 8
; CHECK-NEXT:    [[ENUMTMP7_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[ENUMTMP7]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[ENUMTMP7_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[TMP1:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[CALLRET6]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull align 8 [[TMP1]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[ENUMTMP_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[ENUMTMP]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[ENUMTMP_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[TMP2:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[CALLRET1]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull align 8 [[TMP2]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[TMP3:%.*]] = getelementptr inbounds i8, i8 addrspace(1)* [[THIS:%.*]], i64 32
; CHECK-NEXT:    [[TMP4:%.*]] = bitcast i8 addrspace(1)* [[TMP3]] to i64 addrspace(1)*
; CHECK-NEXT:    [[TMP5:%.*]] = load i64, i64 addrspace(1)* [[TMP4]], align 4
; CHECK-NEXT:    [[ARR_ALLOC_SIZE_VALID:%.*]] = icmp sgt i64 [[TMP5]], -1
; CHECK-NEXT:    br i1 [[ARR_ALLOC_SIZE_VALID]], label [[ARR_ALLOC_BODY0E:%.*]], label [[ARR_ALLOC_THROW0E:%.*]]
; CHECK:       arr.alloc.throw0E:
; CHECK-NEXT:    [[TMP6:%.*]] = call noalias i8 addrspace(1)* @CJ_MCC_NewObjectStub(i8* bitcast (%KlassInfo.0* @"_ZN11std$FS$core26NegativeArraySizeExceptionE.objKlass" to i8*), i32 56)
; CHECK-NEXT:    call void @"_ZN11std$FS$core26NegativeArraySizeException4initEv"(i8 addrspace(1)* [[TMP6]])
; CHECK-NEXT:    call void @CJ_MCC_ThrowException(i8 addrspace(1)* [[TMP6]])
; CHECK-NEXT:    unreachable
; CHECK:       arr.alloc.body0E:
; CHECK-NEXT:    [[TMP7:%.*]] = call noalias i8 addrspace(1)* @CJ_MCC_NewArray32Stub(i64 [[TMP5]], i8* bitcast (%KlassInfo.0* @Char.arrayKlass to i8*))
; CHECK-NEXT:    [[SIZE_IS_ZERO:%.*]] = icmp eq i64 [[TMP5]], 0
; CHECK-NEXT:    br i1 [[SIZE_IS_ZERO]], label [[ARR_INIT_OPT0E:%.*]], label [[ARR_INIT_BODY0E_PREHEADER:%.*]]
; CHECK:       arr.init.body0E.preheader:
; CHECK-NEXT:    [[TMP8:%.*]] = getelementptr inbounds i8, i8 addrspace(1)* [[TMP7]], i64 16
; CHECK-NEXT:    [[TMP9:%.*]] = bitcast i8 addrspace(1)* [[TMP8]] to i32 addrspace(1)*
; CHECK-NEXT:    br label [[ARR_INIT_BODY0E:%.*]]
; CHECK:       arr.init.body0E:
; CHECK-NEXT:    [[ITERATOR_0:%.*]] = phi i64 [ [[TMP11:%.*]], [[ARR_INIT_BODY0E]] ], [ 0, [[ARR_INIT_BODY0E_PREHEADER]] ]
; CHECK-NEXT:    [[TMP10:%.*]] = getelementptr inbounds i32, i32 addrspace(1)* [[TMP9]], i64 [[ITERATOR_0]]
; CHECK-NEXT:    call void @llvm.cj.gcwrite.i32.i32(i32 32, i8 addrspace(1)* [[TMP7]], i32 addrspace(1)* [[TMP10]])
; CHECK-NEXT:    [[TMP11]] = add nuw nsw i64 [[ITERATOR_0]], 1
; CHECK-NEXT:    [[EXITCOND_NOT:%.*]] = icmp eq i64 [[TMP11]], [[TMP5]]
; CHECK-NEXT:    br i1 [[EXITCOND_NOT]], label [[ARR_INIT_OPT0E]], label [[ARR_INIT_BODY0E]]
; CHECK:       arr.init.opt0E:
; CHECK-NEXT:    [[TMP12:%.*]] = getelementptr inbounds i8, i8 addrspace(1)* [[THIS]], i64 40
; CHECK-NEXT:    [[TMP13:%.*]] = bitcast i8 addrspace(1)* [[TMP12]] to i64 addrspace(1)*
; CHECK-NEXT:    [[TMP14:%.*]] = load i64, i64 addrspace(1)* [[TMP13]], align 4
; CHECK-NEXT:    [[ICMPSLT23:%.*]] = icmp sgt i64 [[TMP14]], 0
; CHECK-NEXT:    br i1 [[ICMPSLT23]], label [[WHILE_BODY9072E_LR_PH:%.*]], label [[BLOCK_END9027E:%.*]]
; CHECK:       while.body9072E.lr.ph:
; CHECK-NEXT:    [[TMP15:%.*]] = getelementptr inbounds i8, i8 addrspace(1)* [[THIS]], i64 8
; CHECK-NEXT:    [[TMP16:%.*]] = bitcast i8 addrspace(1)* [[TMP15]] to %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)*
; CHECK-NEXT:    [[TMP17:%.*]] = getelementptr inbounds [[T2_CLE]], %T2_clE* [[CALLRET]], i64 0, i32 1
; CHECK-NEXT:    [[TMP18:%.*]] = getelementptr inbounds [[T2_CLE]], %T2_clE* [[CALLRET]], i64 0, i32 0
; CHECK-NEXT:    [[TMP19:%.*]] = bitcast i8 addrspace(1)* [[TMP7]] to [[ARRAYLAYOUT_CHAR:%.*]] addrspace(1)*
; CHECK-NEXT:    br label [[WHILE_BODY9072E:%.*]]
; CHECK:       while.body9072E:
; CHECK-NEXT:    [[ATOM_17365E_025:%.*]] = phi i64 [ 0, [[WHILE_BODY9072E_LR_PH]] ], [ [[DOTFCA_0_EXTRACT18:%.*]], [[NORMAL0E5:%.*]] ]
; CHECK-NEXT:    [[ATOM_17367E_024:%.*]] = phi i64 [ 0, [[WHILE_BODY9072E_LR_PH]] ], [ [[DOTFCA_0_EXTRACT:%.*]], [[NORMAL0E5]] ]
; CHECK-NEXT:    call void @"_ZN11std$FS$core6Extend4Char8fromUtf8ER_ZN11std$FS$core5ArrayIhEl"(%T2_clE* noalias nonnull sret([[T2_CLE]]) [[CALLRET]], i8 addrspace(1)* [[THIS]], %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)* [[TMP16]], i64 [[ATOM_17367E_024]])
; CHECK-NEXT:    [[ICMPUGE_NOT:%.*]] = icmp ult i64 [[ATOM_17365E_025]], [[TMP5]]
; CHECK-NEXT:    br i1 [[ICMPUGE_NOT]], label [[IF_ELSE19175E:%.*]], label [[IF_THEN19175E:%.*]]
; CHECK:       if.then19175E:
; CHECK-NEXT:    [[TMP20:%.*]] = call noalias i8 addrspace(1)* @CJ_MCC_NewObjectStub(i8* bitcast (%KlassInfo.0* @"_ZN11std$FS$core25IndexOutOfBoundsExceptionE.objKlass" to i8*), i32 56)
; CHECK-NEXT:    call void @"_ZN11std$FS$core25IndexOutOfBoundsException4initEv"(i8 addrspace(1)* [[TMP20]])
; CHECK-NEXT:    call void @CJ_MCC_ThrowException(i8 addrspace(1)* [[TMP20]])
; CHECK-NEXT:    unreachable
; CHECK:       if.else19175E:
; CHECK-NEXT:    [[TMP21:%.*]] = load i64, i64* [[TMP17]], align 4
; CHECK-NEXT:    [[TMP22:%.*]] = load i32, i32* [[TMP18]], align 4
; CHECK-NEXT:    [[ARR_IDX_SET_GEP:%.*]] = getelementptr inbounds [[ARRAYLAYOUT_CHAR]], [[ARRAYLAYOUT_CHAR]] addrspace(1)* [[TMP19]], i64 0, i32 1, i64 [[ATOM_17365E_025]]
; CHECK-NEXT:    call void @llvm.cj.gcwrite.i32.i32(i32 [[TMP22]], i8 addrspace(1)* [[TMP7]], i32 addrspace(1)* [[ARR_IDX_SET_GEP]])
; CHECK-NEXT:    [[TMP23:%.*]] = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 [[ATOM_17367E_024]], i64 [[TMP21]])
; CHECK-NEXT:    [[DOTFCA_0_EXTRACT]] = extractvalue { i64, i1 } [[TMP23]], 0
; CHECK-NEXT:    [[DOTFCA_1_EXTRACT:%.*]] = extractvalue { i64, i1 } [[TMP23]], 1
; CHECK-NEXT:    br i1 [[DOTFCA_1_EXTRACT]], label [[OVERFLOW0E:%.*]], label [[NORMAL0E:%.*]], !prof [[PROF10]]
; CHECK:       normal0E:
; CHECK-NEXT:    [[TMP24:%.*]] = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 [[ATOM_17365E_025]], i64 1)
; CHECK-NEXT:    [[DOTFCA_1_EXTRACT19:%.*]] = extractvalue { i64, i1 } [[TMP24]], 1
; CHECK-NEXT:    br i1 [[DOTFCA_1_EXTRACT19]], label [[OVERFLOW0E4:%.*]], label [[NORMAL0E5]], !prof [[PROF10]]
; CHECK:       overflow0E:
; CHECK-NEXT:    call void @"_ZN11std$FS$core6String23createStringFromLiteralE"(%"record._ZN11std$FS$core6StringE"* noalias nonnull sret(%"record._ZN11std$FS$core6StringE") [[CALLRET1]], i8* getelementptr inbounds ([4 x i8], [4 x i8]* @"$const_string.29", i64 0, i64 0), i64 3)
; CHECK-NEXT:    [[TMP25:%.*]] = addrspacecast %"record._ZN11std$FS$core6StringE"* [[CALLRET1]] to %"record._ZN11std$FS$core6StringE" addrspace(1)*
; CHECK-NEXT:    [[TMP26:%.*]] = call i8 addrspace(1)* @"rt$CreateOverflowException_msg"(i8 addrspace(1)* null, %"record._ZN11std$FS$core6StringE" addrspace(1)* [[TMP25]])
; CHECK-NEXT:    call void @CJ_MCC_ThrowException(i8 addrspace(1)* [[TMP26]])
; CHECK-NEXT:    unreachable
; CHECK:       normal0E5:
; CHECK-NEXT:    [[DOTFCA_0_EXTRACT18]] = extractvalue { i64, i1 } [[TMP24]], 0
; CHECK-NEXT:    [[TMP27:%.*]] = load i64, i64 addrspace(1)* [[TMP13]], align 4
; CHECK-NEXT:    [[ICMPSLT:%.*]] = icmp slt i64 [[DOTFCA_0_EXTRACT]], [[TMP27]]
; CHECK-NEXT:    br i1 [[ICMPSLT]], label [[WHILE_BODY9072E]], label [[BLOCK_END9027E]]
; CHECK:       overflow0E4:
; CHECK-NEXT:    call void @"_ZN11std$FS$core6String23createStringFromLiteralE"(%"record._ZN11std$FS$core6StringE"* noalias nonnull sret(%"record._ZN11std$FS$core6StringE") [[CALLRET6]], i8* getelementptr inbounds ([4 x i8], [4 x i8]* @"$const_string.29", i64 0, i64 0), i64 3)
; CHECK-NEXT:    [[TMP28:%.*]] = addrspacecast %"record._ZN11std$FS$core6StringE"* [[CALLRET6]] to %"record._ZN11std$FS$core6StringE" addrspace(1)*
; CHECK-NEXT:    [[TMP29:%.*]] = call i8 addrspace(1)* @"rt$CreateOverflowException_msg"(i8 addrspace(1)* null, %"record._ZN11std$FS$core6StringE" addrspace(1)* [[TMP28]])
; CHECK-NEXT:    call void @CJ_MCC_ThrowException(i8 addrspace(1)* [[TMP29]])
; CHECK-NEXT:    unreachable
; CHECK:       block.end9027E:
; CHECK-NEXT:    [[CHARARRAY_SROA_0_0__SROA_IDX:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[TMP0:%.*]], i64 0, i32 0
; CHECK-NEXT:    store i8 addrspace(1)* [[TMP7]], i8 addrspace(1)** [[CHARARRAY_SROA_0_0__SROA_IDX]], align 8
; CHECK-NEXT:    [[CHARARRAY_SROA_4_0__SROA_IDX10:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[TMP0]], i64 0, i32 1
; CHECK-NEXT:    store i64 0, i64* [[CHARARRAY_SROA_4_0__SROA_IDX10]], align 4
; CHECK-NEXT:    [[CHARARRAY_SROA_5_0__SROA_IDX11:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[TMP0]], i64 0, i32 2
; CHECK-NEXT:    store i64 [[TMP5]], i64* [[CHARARRAY_SROA_5_0__SROA_IDX11]], align 4
; CHECK-NEXT:    ret void
;

; CHECK-LABEL: @hoo3(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[ENUMTMP38:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[ENUMTMP37:%.*]] = alloca %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", align 8
; CHECK-NEXT:    [[CALLRET36:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[ENUMTMP32:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[CALLRET31:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[ENUMTMP26:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[CALLRET25:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[ENUMTMP17:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[CALLRET16:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[VALUE:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[CALLRET9:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[CALLRET7:%.*]] = alloca %"record._ZN17std$FS$collection11std$FS$core6OptionIcE", align 8
; CHECK-NEXT:    [[STRINGARRAY:%.*]] = alloca %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", align 8
; CHECK-NEXT:    [[ENUMTMP6:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[CALLRET5:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[ENUMTMP:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[CALLRET:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[BLOCK16070VAL:%.*]] = alloca %"record._ZN11std$FS$core6StringE", align 8
; CHECK-NEXT:    [[ENUMTMP38_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[ENUMTMP38]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[ENUMTMP38_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[ENUMTMP37_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[ENUMTMP37]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[ENUMTMP37_0_SROA_CAST]], i8 0, i64 24, i1 false)
; CHECK-NEXT:    [[TMP1:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[CALLRET36]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull align 8 [[TMP1]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[ENUMTMP32_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[ENUMTMP32]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[ENUMTMP32_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[CALLRET31_0_SROA_CAST46:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[CALLRET31]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[CALLRET31_0_SROA_CAST46]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[ENUMTMP26_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[ENUMTMP26]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[ENUMTMP26_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[CALLRET25_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[CALLRET25]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[CALLRET25_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[ENUMTMP17_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[ENUMTMP17]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[ENUMTMP17_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[TMP2:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[CALLRET16]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull align 8 [[TMP2]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[TMP3:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[VALUE]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull align 8 [[TMP3]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[TMP4:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[CALLRET9]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull align 8 [[TMP4]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[TMP5:%.*]] = bitcast %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[STRINGARRAY]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull align 8 [[TMP5]], i8 0, i64 24, i1 false)
; CHECK-NEXT:    [[ENUMTMP6_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[ENUMTMP6]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[ENUMTMP6_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[CALLRET5_0_SROA_CAST45:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[CALLRET5]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[CALLRET5_0_SROA_CAST45]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[ENUMTMP_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[ENUMTMP]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[ENUMTMP_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[TMP6:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[CALLRET]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull align 8 [[TMP6]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[BLOCK16070VAL_0_SROA_CAST:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[BLOCK16070VAL]] to i8*
; CHECK-NEXT:    call void @llvm.cj.memset.p0i8(i8* nonnull [[BLOCK16070VAL_0_SROA_CAST]], i8 0, i64 16, i1 false)
; CHECK-NEXT:    [[TMP7:%.*]] = call i8* @CJ_MCC_GetObjClass(i8 addrspace(1)* [[IT:%.*]])
; CHECK-NEXT:    [[TMP8:%.*]] = getelementptr i8, i8* [[TMP7]], i64 32
; CHECK-NEXT:    [[TMP9:%.*]] = bitcast i8* [[TMP8]] to i64**
; CHECK-NEXT:    [[TMP10:%.*]] = load i64*, i64** [[TMP9]], align 8
; CHECK-NEXT:    [[TMP11:%.*]] = call i8* @CJ_MCC_GetFuncPtrFromItab(i64* [[TMP10]], i32 17, i32 2821, i8* getelementptr inbounds ([11 x i8], [11 x i8]* @"$const_string.35", i64 0, i64 0))
; CHECK-NEXT:    [[TMP12:%.*]] = bitcast i8* [[TMP11]] to i64 (i8 addrspace(1)*)*
; CHECK-NEXT:    [[TMP13:%.*]] = call i64 [[TMP12]](i8 addrspace(1)* [[IT]])
; CHECK-NEXT:    [[ICMPEQ:%.*]] = icmp eq i64 [[TMP13]], 0
; CHECK-NEXT:    br i1 [[ICMPEQ]], label [[COMMON_RET:%.*]], label [[IF_ELSE16086E:%.*]]
; CHECK:       common.ret:
; CHECK-NEXT:    [[DOTSINK47:%.*]] = phi i8* [ [[TMP1]], [[IF_ELSE28490E:%.*]] ], [ bitcast (%"record._ZN11std$FS$core6StringE"* @"_ZN15std$$collection22$__STRING_LITERAL__$22E" to i8*), [[ENTRY:%.*]] ]
; CHECK-NEXT:    [[TMP14:%.*]] = bitcast %"record._ZN11std$FS$core6StringE"* [[TMP0:%.*]] to i8*
; CHECK-NEXT:    call void @llvm.memcpy.p0i8.p0i8.i64(i8* noundef nonnull align 8 dereferenceable(16) [[TMP14]], i8* noundef nonnull align 8 dereferenceable(16) [[DOTSINK47]], i64 16, i1 false)
; CHECK-NEXT:    ret void
; CHECK:       if.else16086E:
; CHECK-NEXT:    [[TMP15:%.*]] = call { i64, i1 } @llvm.smul.with.overflow.i64(i64 [[TMP13]], i64 2)
; CHECK-NEXT:    [[DOTFCA_1_EXTRACT:%.*]] = extractvalue { i64, i1 } [[TMP15]], 1
; CHECK-NEXT:    br i1 [[DOTFCA_1_EXTRACT]], label [[OVERFLOW0E:%.*]], label [[NORMAL0E:%.*]], !prof [[PROF10]]
; CHECK:       normal0E:
; CHECK-NEXT:    [[DOTFCA_0_EXTRACT:%.*]] = extractvalue { i64, i1 } [[TMP15]], 0
; CHECK-NEXT:    [[TMP16:%.*]] = or i64 [[DOTFCA_0_EXTRACT]], 1
; CHECK-NEXT:    [[ARR_ALLOC_SIZE_VALID:%.*]] = icmp sgt i64 [[TMP16]], -1
; CHECK-NEXT:    br i1 [[ARR_ALLOC_SIZE_VALID]], label [[ARR_ALLOC_BODY0E:%.*]], label [[ARR_ALLOC_THROW0E:%.*]]
; CHECK:       overflow0E:
; CHECK-NEXT:    call void @"_ZN11std$FS$core6String23createStringFromLiteralE"(%"record._ZN11std$FS$core6StringE"* noalias nonnull sret(%"record._ZN11std$FS$core6StringE") [[CALLRET]], i8* getelementptr inbounds ([4 x i8], [4 x i8]* @"$const_string.30", i64 0, i64 0), i64 3)
; CHECK-NEXT:    [[TMP17:%.*]] = addrspacecast %"record._ZN11std$FS$core6StringE"* [[CALLRET]] to %"record._ZN11std$FS$core6StringE" addrspace(1)*
; CHECK-NEXT:    [[TMP18:%.*]] = call i8 addrspace(1)* @"rt$CreateOverflowException_msg"(i8 addrspace(1)* null, %"record._ZN11std$FS$core6StringE" addrspace(1)* [[TMP17]])
; CHECK-NEXT:    call void @CJ_MCC_ThrowException(i8 addrspace(1)* [[TMP18]])
; CHECK-NEXT:    unreachable
; CHECK:       arr.alloc.throw0E:
; CHECK-NEXT:    [[TMP19:%.*]] = call noalias i8 addrspace(1)* @CJ_MCC_NewObjectStub(i8* bitcast (%KlassInfo.0* @"_ZN11std$FS$core26NegativeArraySizeExceptionE.objKlass" to i8*), i32 56)
; CHECK-NEXT:    call void @"_ZN11std$FS$core26NegativeArraySizeException4initEv"(i8 addrspace(1)* [[TMP19]])
; CHECK-NEXT:    call void @CJ_MCC_ThrowException(i8 addrspace(1)* [[TMP19]])
; CHECK-NEXT:    unreachable
; CHECK:       arr.alloc.body0E:
; CHECK-NEXT:    [[TMP20:%.*]] = call noalias i8 addrspace(1)* @CJ_MCC_NewArrayStub(i64 [[TMP16]], i8* bitcast (%KlassInfo.0* @"_ZN11std$FS$core6StringE.arrayKlass" to i8*))
; CHECK-NEXT:    [[TMP21:%.*]] = getelementptr inbounds i8, i8 addrspace(1)* [[TMP20]], i64 16
; CHECK-NEXT:    [[TMP22:%.*]] = bitcast i8 addrspace(1)* [[TMP21]] to %"record._ZN11std$FS$core6StringE" addrspace(1)*
; CHECK-NEXT:    br label [[ARR_INIT_BODY0E:%.*]]
; CHECK:       arr.init.body0E:
; CHECK-NEXT:    [[ITERATOR_0:%.*]] = phi i64 [ 0, [[ARR_ALLOC_BODY0E]] ], [ [[TMP25:%.*]], [[ARR_INIT_BODY0E]] ]
; CHECK-NEXT:    [[TMP23:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core6StringE", %"record._ZN11std$FS$core6StringE" addrspace(1)* [[TMP22]], i64 [[ITERATOR_0]]
; CHECK-NEXT:    [[TMP24:%.*]] = bitcast %"record._ZN11std$FS$core6StringE" addrspace(1)* [[TMP23]] to i8 addrspace(1)*
; CHECK-NEXT:    call void @llvm.cj.gcwrite.struct.p0i8.i64(i8 addrspace(1)* [[TMP20]], i8 addrspace(1)* [[TMP24]], i8* bitcast (%"record._ZN11std$FS$core6StringE"* @"_ZN11std$FS$core6String5emptyE" to i8*), i64 16)
; CHECK-NEXT:    [[TMP25]] = add nuw nsw i64 [[ITERATOR_0]], 1
; CHECK-NEXT:    [[EXITCOND_NOT:%.*]] = icmp eq i64 [[TMP25]], [[TMP16]]
; CHECK-NEXT:    br i1 [[EXITCOND_NOT]], label [[ARR_INIT_OPT0E:%.*]], label [[ARR_INIT_BODY0E]]
; CHECK:       arr.init.opt0E:
; CHECK-NEXT:    [[ATOM_17657E_SROA_0_0__SROA_IDX11:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[STRINGARRAY]], i64 0, i32 0
; CHECK-NEXT:    store i8 addrspace(1)* [[TMP20]], i8 addrspace(1)** [[ATOM_17657E_SROA_0_0__SROA_IDX11]], align 8
; CHECK-NEXT:    [[ATOM_17657E_SROA_4_0__SROA_IDX14:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[STRINGARRAY]], i64 0, i32 1
; CHECK-NEXT:    store i64 0, i64* [[ATOM_17657E_SROA_4_0__SROA_IDX14]], align 4
; CHECK-NEXT:    [[ATOM_17657E_SROA_5_0__SROA_IDX17:%.*]] = getelementptr inbounds %"record._ZN11std$FS$core11std$FS$core5ArrayIlE", %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[STRINGARRAY]], i64 0, i32 2
; CHECK-NEXT:    store i64 [[TMP16]], i64* [[ATOM_17657E_SROA_5_0__SROA_IDX17]], align 4
; CHECK-NEXT:    call void @llvm.cj.gcwrite.struct.p0i8.i64(i8 addrspace(1)* [[TMP20]], i8 addrspace(1)* [[TMP21]], i8* bitcast (%"record._ZN11std$FS$core6StringE"* @"_ZN15std$$collection22$__STRING_LITERAL__$23E" to i8*), i64 16)
; CHECK-NEXT:    [[TMP26:%.*]] = call i8* @CJ_MCC_GetObjClass(i8 addrspace(1)* [[IT]])
; CHECK-NEXT:    [[TMP27:%.*]] = getelementptr i8, i8* [[TMP26]], i64 32
; CHECK-NEXT:    [[TMP28:%.*]] = bitcast i8* [[TMP27]] to i64**
; CHECK-NEXT:    [[TMP29:%.*]] = load i64*, i64** [[TMP28]], align 8
; CHECK-NEXT:    [[TMP30:%.*]] = call i8* @CJ_MCC_GetFuncPtrFromItab(i64* [[TMP29]], i32 18, i32 110, i8* getelementptr inbounds ([11 x i8], [11 x i8]* @"$const_string.33", i64 0, i64 0))
; CHECK-NEXT:    [[TMP31:%.*]] = bitcast i8* [[TMP30]] to i8 addrspace(1)* (i8 addrspace(1)*)*
; CHECK-NEXT:    [[TMP32:%.*]] = call i8 addrspace(1)* [[TMP31]](i8 addrspace(1)* [[IT]])
; CHECK-NEXT:    [[TMP33:%.*]] = getelementptr inbounds %"record._ZN17std$FS$collection11std$FS$core6OptionIcE", %"record._ZN17std$FS$collection11std$FS$core6OptionIcE"* [[CALLRET7]], i64 0, i32 0
; CHECK-NEXT:    [[TMP34:%.*]] = getelementptr inbounds %"record._ZN17std$FS$collection11std$FS$core6OptionIcE", %"record._ZN17std$FS$collection11std$FS$core6OptionIcE"* [[CALLRET7]], i64 0, i32 1
; CHECK-NEXT:    br label [[BLOCK_BODY16122E:%.*]]
; CHECK:       block.body16122E:
; CHECK-NEXT:    [[ATOM_17659E_0:%.*]] = phi i64 [ 1, [[ARR_INIT_OPT0E]] ], [ [[DOTFCA_0_EXTRACT29:%.*]], [[IF_ELSE28455E:%.*]] ]
; CHECK-NEXT:    [[TMP35:%.*]] = call i8* @CJ_MCC_GetObjClass(i8 addrspace(1)* [[TMP32]])
; CHECK-NEXT:    [[TMP36:%.*]] = getelementptr i8, i8* [[TMP35]], i64 32
; CHECK-NEXT:    [[TMP37:%.*]] = bitcast i8* [[TMP36]] to i64**
; CHECK-NEXT:    [[TMP38:%.*]] = load i64*, i64** [[TMP37]], align 8
; CHECK-NEXT:    [[TMP39:%.*]] = call i8* @CJ_MCC_GetFuncPtrFromItab(i64* [[TMP38]], i32 10, i32 907, i8* getelementptr inbounds ([7 x i8], [7 x i8]* @"$const_string.34", i64 0, i64 0))
; CHECK-NEXT:    [[TMP40:%.*]] = bitcast i8* [[TMP39]] to void (%"record._ZN17std$FS$collection11std$FS$core6OptionIcE"*, i8 addrspace(1)*)*
; CHECK-NEXT:    call void [[TMP40]](%"record._ZN17std$FS$collection11std$FS$core6OptionIcE"* noalias nonnull sret(%"record._ZN17std$FS$collection11std$FS$core6OptionIcE") [[CALLRET7]], i8 addrspace(1)* [[TMP32]])
; CHECK-NEXT:    [[TMP41:%.*]] = load i1, i1* [[TMP33]], align 1
; CHECK-NEXT:    br i1 [[TMP41]], label [[NORMAL0E30:%.*]], label [[IF_ELSE16170E:%.*]]
; CHECK:       if.else16170E:
; CHECK-NEXT:    [[TMP42:%.*]] = load i32, i32* [[TMP34]], align 4
; CHECK-NEXT:    call void @"_ZN11std$FS$core6Extend4Char8toStringEv"(%"record._ZN11std$FS$core6StringE"* noalias nonnull sret(%"record._ZN11std$FS$core6StringE") [[CALLRET9]], i32 [[TMP42]])
; CHECK-NEXT:    call void @llvm.memcpy.p0i8.p0i8.i64(i8* noundef nonnull align 8 dereferenceable(16) [[TMP3]], i8* noundef nonnull align 8 dereferenceable(16) [[TMP4]], i64 16, i1 false)
; CHECK-NEXT:    [[ICMPUGE10_NOT:%.*]] = icmp ult i64 [[ATOM_17659E_0]], [[TMP16]]
; CHECK-NEXT:    br i1 [[ICMPUGE10_NOT]], label [[IF_ELSE28420E:%.*]], label [[IF_THEN28420E:%.*]]
; CHECK:       if.then28420E:
; CHECK-NEXT:    [[TMP43:%.*]] = call noalias i8 addrspace(1)* @CJ_MCC_NewObjectStub(i8* bitcast (%KlassInfo.0* @"_ZN11std$FS$core25IndexOutOfBoundsExceptionE.objKlass" to i8*), i32 56)
; CHECK-NEXT:    call void @"_ZN11std$FS$core25IndexOutOfBoundsException4initEv"(i8 addrspace(1)* [[TMP43]])
; CHECK-NEXT:    call void @CJ_MCC_ThrowException(i8 addrspace(1)* [[TMP43]])
; CHECK-NEXT:    unreachable
; CHECK:       if.else28420E:
; CHECK-NEXT:    [[TMP44:%.*]] = load i8 addrspace(1)*, i8 addrspace(1)** [[ATOM_17657E_SROA_0_0__SROA_IDX11]], align 8
; CHECK-NEXT:    [[TMP45:%.*]] = bitcast i8 addrspace(1)* [[TMP44]] to %"ArrayLayout._ZN11std$FS$core6StringE" addrspace(1)*
; CHECK-NEXT:    [[ARR_IDX_SET_GEP11:%.*]] = getelementptr inbounds %"ArrayLayout._ZN11std$FS$core6StringE", %"ArrayLayout._ZN11std$FS$core6StringE" addrspace(1)* [[TMP45]], i64 0, i32 1, i64 [[ATOM_17659E_0]]
; CHECK-NEXT:    [[TMP46:%.*]] = bitcast %"record._ZN11std$FS$core6StringE" addrspace(1)* [[ARR_IDX_SET_GEP11]] to i8 addrspace(1)*
; CHECK-NEXT:    call void @llvm.cj.gcwrite.struct.p0i8.i64(i8 addrspace(1)* [[TMP44]], i8 addrspace(1)* [[TMP46]], i8* nonnull [[TMP3]], i64 16)
; CHECK-NEXT:    [[TMP47:%.*]] = call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 [[ATOM_17659E_0]], i64 1)
; CHECK-NEXT:    [[DOTFCA_0_EXTRACT24:%.*]] = extractvalue { i64, i1 } [[TMP47]], 0
; CHECK-NEXT:    [[DOTFCA_1_EXTRACT25:%.*]] = extractvalue { i64, i1 } [[TMP47]], 1
; CHECK-NEXT:    br i1 [[DOTFCA_1_EXTRACT25]], label [[OVERFLOW0E14:%.*]], label [[NORMAL0E15:%.*]], !prof [[PROF10]]
; CHECK:       normal0E15:
; CHECK-NEXT:    [[ICMPUGE19_NOT:%.*]] = icmp ult i64 [[DOTFCA_0_EXTRACT24]], [[TMP16]]
; CHECK-NEXT:    br i1 [[ICMPUGE19_NOT]], label [[IF_ELSE28455E]], label [[IF_THEN28455E:%.*]]
; CHECK:       overflow0E14:
; CHECK-NEXT:    call void @"_ZN11std$FS$core6String23createStringFromLiteralE"(%"record._ZN11std$FS$core6StringE"* noalias nonnull sret(%"record._ZN11std$FS$core6StringE") [[CALLRET16]], i8* getelementptr inbounds ([4 x i8], [4 x i8]* @"$const_string.29", i64 0, i64 0), i64 3)
; CHECK-NEXT:    [[TMP48:%.*]] = addrspacecast %"record._ZN11std$FS$core6StringE"* [[CALLRET16]] to %"record._ZN11std$FS$core6StringE" addrspace(1)*
; CHECK-NEXT:    [[TMP49:%.*]] = call i8 addrspace(1)* @"rt$CreateOverflowException_msg"(i8 addrspace(1)* null, %"record._ZN11std$FS$core6StringE" addrspace(1)* [[TMP48]])
; CHECK-NEXT:    call void @CJ_MCC_ThrowException(i8 addrspace(1)* [[TMP49]])
; CHECK-NEXT:    unreachable
; CHECK:       if.then28455E:
; CHECK-NEXT:    [[TMP50:%.*]] = call noalias i8 addrspace(1)* @CJ_MCC_NewObjectStub(i8* bitcast (%KlassInfo.0* @"_ZN11std$FS$core25IndexOutOfBoundsExceptionE.objKlass" to i8*), i32 56)
; CHECK-NEXT:    call void @"_ZN11std$FS$core25IndexOutOfBoundsException4initEv"(i8 addrspace(1)* [[TMP50]])
; CHECK-NEXT:    call void @CJ_MCC_ThrowException(i8 addrspace(1)* [[TMP50]])
; CHECK-NEXT:    unreachable
; CHECK:       if.else28455E:
; CHECK-NEXT:    [[TMP51:%.*]] = load i8 addrspace(1)*, i8 addrspace(1)** [[ATOM_17657E_SROA_0_0__SROA_IDX11]], align 8
; CHECK-NEXT:    [[TMP52:%.*]] = bitcast i8 addrspace(1)* [[TMP51]] to %"ArrayLayout._ZN11std$FS$core6StringE" addrspace(1)*
; CHECK-NEXT:    [[ARR_IDX_SET_GEP20:%.*]] = getelementptr inbounds %"ArrayLayout._ZN11std$FS$core6StringE", %"ArrayLayout._ZN11std$FS$core6StringE" addrspace(1)* [[TMP52]], i64 0, i32 1, i64 [[DOTFCA_0_EXTRACT24]]
; CHECK-NEXT:    [[TMP53:%.*]] = bitcast %"record._ZN11std$FS$core6StringE" addrspace(1)* [[ARR_IDX_SET_GEP20]] to i8 addrspace(1)*
; CHECK-NEXT:    call void @llvm.cj.gcwrite.struct.p0i8.i64(i8 addrspace(1)* [[TMP51]], i8 addrspace(1)* [[TMP53]], i8* bitcast (%"record._ZN11std$FS$core6StringE"* @"_ZN15std$$collection22$__STRING_LITERAL__$24E" to i8*), i64 16)
; CHECK-NEXT:    [[DOTFCA_0_EXTRACT29]] = add nuw i64 [[ATOM_17659E_0]], 2
; CHECK-NEXT:    br label [[BLOCK_BODY16122E]]
; CHECK:       normal0E30:
; CHECK-NEXT:    [[ICMPUGE34_NOT:%.*]] = icmp ult i64 [[DOTFCA_0_EXTRACT]], [[TMP16]]
; CHECK-NEXT:    br i1 [[ICMPUGE34_NOT]], label [[IF_ELSE28490E]], label [[IF_THEN28490E:%.*]]
; CHECK:       if.then28490E:
; CHECK-NEXT:    [[TMP54:%.*]] = call noalias i8 addrspace(1)* @CJ_MCC_NewObjectStub(i8* bitcast (%KlassInfo.0* @"_ZN11std$FS$core25IndexOutOfBoundsExceptionE.objKlass" to i8*), i32 56)
; CHECK-NEXT:    call void @"_ZN11std$FS$core25IndexOutOfBoundsException4initEv"(i8 addrspace(1)* [[TMP54]])
; CHECK-NEXT:    call void @CJ_MCC_ThrowException(i8 addrspace(1)* [[TMP54]])
; CHECK-NEXT:    unreachable
; CHECK:       if.else28490E:
; CHECK-NEXT:    [[TMP55:%.*]] = load i8 addrspace(1)*, i8 addrspace(1)** [[ATOM_17657E_SROA_0_0__SROA_IDX11]], align 8
; CHECK-NEXT:    [[TMP56:%.*]] = bitcast i8 addrspace(1)* [[TMP55]] to %"ArrayLayout._ZN11std$FS$core6StringE" addrspace(1)*
; CHECK-NEXT:    [[ARR_IDX_SET_GEP35:%.*]] = getelementptr inbounds %"ArrayLayout._ZN11std$FS$core6StringE", %"ArrayLayout._ZN11std$FS$core6StringE" addrspace(1)* [[TMP56]], i64 0, i32 1, i64 [[DOTFCA_0_EXTRACT]]
; CHECK-NEXT:    [[TMP57:%.*]] = bitcast %"record._ZN11std$FS$core6StringE" addrspace(1)* [[ARR_IDX_SET_GEP35]] to i8 addrspace(1)*
; CHECK-NEXT:    call void @llvm.cj.gcwrite.struct.p0i8.i64(i8 addrspace(1)* [[TMP55]], i8 addrspace(1)* [[TMP57]], i8* bitcast (%"record._ZN11std$FS$core6StringE"* @"_ZN15std$$collection22$__STRING_LITERAL__$25E" to i8*), i64 16)
; CHECK-NEXT:    [[TMP58:%.*]] = addrspacecast %"record._ZN11std$FS$core11std$FS$core5ArrayIlE"* [[STRINGARRAY]] to %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)*
; CHECK-NEXT:    call void @"_ZN11std$FS$core6String4joinER_ZN11std$FS$core5ArrayIR_ZN11std$FS$core6StringEER_ZN11std$FS$core6StringE"(%"record._ZN11std$FS$core6StringE"* noalias nonnull sret(%"record._ZN11std$FS$core6StringE") [[CALLRET36]], i8 addrspace(1)* null, %"record._ZN11std$FS$core11std$FS$core5ArrayIlE" addrspace(1)* [[TMP58]], i8 addrspace(1)* null, %"record._ZN11std$FS$core6StringE" addrspace(1)* addrspacecast (%"record._ZN11std$FS$core6StringE"* @"_ZN11std$FS$core6String5emptyE" to %"record._ZN11std$FS$core6StringE" addrspace(1)*))
; CHECK-NEXT:    br label [[COMMON_RET]]
;

attributes #0 = { readonly "GCRoot" }

!llvm.module.flags = !{!9}

; CHECK:         !0 = !{!"R_ZN11std$FS$core5ArrayIlE"}
; CHECK-NEXT:    !1 = !{!"R_ZN11std$FS$core5ArrayIR_ZN11std$FS$core6StringEE"}
; CHECK-NEXT:    !2 = !{!"A1_hE"}
; CHECK-NEXT:    !3 = !{!"R_ZN11std$FS$core5ArrayIhE"}
; CHECK-NEXT:    !4 = !{!"R_ZN11std$FS$core6StringE"}
; CHECK-NEXT:    !5 = !{i32 2, !"CJBC", i32 1}
; CHECK-NEXT:    !6 = distinct !{!"record._ZN11std$FS$core11std$FS$core5ArrayIlE"}
; CHECK-NEXT:    !7 = !{!"record._ZN11std$FS$core11std$FS$core5ArrayIlE"}
; CHECK-NEXT:    !8 = distinct !{!"record._ZN11std$FS$core11std$FS$core5ArrayIlE"}
; CHECK-NEXT:    !9 = !{!"record._ZN11std$FS$core6StringE"}
; CHECK-NEXT:    !10 = !{!"branch_weights", i32 1, i32 2000}
; CHECK-NEXT:    !11 = !{!12}
; CHECK-NEXT:    !12 = distinct !{!12, !13, !"_ZN17std$FS$collection13StringBuilder25fromCharIndexToUInt8IndexEll: argument 0"}
; CHECK-NEXT:    !13 = distinct !{!13, !"_ZN17std$FS$collection13StringBuilder25fromCharIndexToUInt8IndexEll"}
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
