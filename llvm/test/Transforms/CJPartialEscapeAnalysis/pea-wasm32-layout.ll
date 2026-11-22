; RUN: opt < %s '-passes=cj-pea' -S | FileCheck %s
; REQUIRES: webassembly-registered-target
; On wasm32 the TypeInfo pointer is 4 bytes: a stack-allocated object must keep
; the heap layout (payload at offset 4, array data at offset 12) and span the
; 8-byte object granule, so the alloca type is packed and tail-padded.

target datalayout = "e-m:e-p:32:32-p10:8:8-p20:8:8-i64:64-n32:64-S128-ni:1:10:20"
target triple = "wasm32-unknown-wasi"

; CHECK-LABEL: @foo(
; CHECK: %0 = alloca <{ %TypeInfo*, { %ArrayBase, [33 x i64] }, [4 x i8] }>, align 8
; CHECK: %1 = alloca <{ %TypeInfo*, { %ArrayBase, [50 x i64] }, [4 x i8] }>, align 8
; CHECK: %3 = alloca <{ %TypeInfo*, %ObjLayout._ZN7default8CrcCheck, [4 x i8] }>, align 8
; CHECK: [[OBJ:%[0-9]+]] = getelementptr inbounds i8, i8* %{{[0-9]+}}, i32 4
; CHECK-NEXT: call void @llvm.cj.memset.p0i8(i8* [[OBJ]], i8 0, i64 100, i1 false)
; CHECK: getelementptr inbounds <{ %TypeInfo*, { %ArrayBase, [50 x i64] }, [4 x i8] }>, {{.*}}* %1, i32 0, i32 1
; CHECK: store i64 50, i64* %{{[0-9]+}}, align 8
; CHECK: [[DATA:%[0-9]+]] = getelementptr inbounds i8, i8* %{{[0-9]+}}, i32 12
; CHECK-NEXT: call void @llvm.memset.p0i8.i64(i8* [[DATA]], i8 0, i64 400, i1 false)

%BitMap = type { i32, [0 x i8] }
%_ZN7default8CrcCheck.ti.reflectType = type { i32, i32, i32, i32, i32, i8* }
%ObjLayout._ZN7default8CrcCheck = type { %record._ZN8std.core5ArrayIlE, %record._ZN8std.core5ArrayIlE, %record._ZN8std.core5ArrayIlE, i64, i64, i64 }
%record._ZN8std.core5ArrayIlE = type { i8 addrspace(1)*, i64, i64 }
%ArrayLayout.Int64 = type { %ArrayBase, [0 x i64] }
%ArrayBase = type { i64 }
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i32*, i8*, i8*, i8*, %TypeInfo*, i8*, i8* }
%TypeTemplate = type { i8*, i8, i8, i16, i16, i8*, i8*, i8*, i8* }

@_ZN7default20var_1715509008039_60E = global i8 0, align 8
@A1_lE.typeName = internal global [6 x i8] c"A1_lE\00", align 1
@_ZN7default8CrcCheck.ti = internal global %TypeInfo {i8* getelementptr inbounds ([17 x i8], [17 x i8]* @"default$CrcCheck.name", i32 0, i32 0), i8 -128, i8 0, i16 2, i32 16, %BitMap* null, i32 0, i8 8, i8 0, i32* getelementptr inbounds ([1 x i32], [1 x i32]* @"default$CrcCheck.ti.offsets", i32 0, i32 0), i8* null, i8* null, i8* bitcast ([1 x %TypeInfo*]* @"default$CrcCheck.ti.fields" to i8*), %TypeInfo* @"std.core$Object.ti", i8* null, i8* bitcast ([1 x i8*]* @"default$CrcCheck.fieldNames" to i8*)}, !RelatedType !1
@"default$CrcCheck.name" = internal global [17 x i8] c"default$CrcCheck\00", align 1
@"std.core$Object.ti" = external global %TypeInfo
@"default$CrcCheck.ti.offsets" = internal global [1 x i32] [i32 0]
@"default$CrcCheck.ti.fields" = internal global [1 x %TypeInfo*] [%TypeInfo* @"std.core$Object.ti"]
@"default$CrcCheck.fieldNames" = internal global [1 x i8*] [i8* getelementptr inbounds ([3 x i8], [3 x i8]* @"default$CrcCheck.field.1.name", i32 0, i32 0)]
@"default$CrcCheck.field.1.name" = internal global [3 x i8] c"aa\00", align 1
@"RawArray<Int64>.ti" = internal global %TypeInfo { i8* getelementptr inbounds ([16 x i8], [16 x i8]* @"RawArray<Int64>.name", i32 0, i32 0), i8 -126, i8 0, i16 0, i32 8, %BitMap* null, i32 0, i8 8, i8  0, i32* null, i8* bitcast (%TypeTemplate* @RawArray.tt to i8*), i8* null, i8* null, %TypeInfo* @Int64.ti, i8* null, i8* null }, !RelatedType !0
@"RawArray<Int64>.name" = internal global [16 x i8] c"RawArray<Int64>\00", align 1
@RawArray.tt = external global %TypeTemplate
@Int64.ti = external global %TypeInfo

declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)

declare i8 addrspace(1)* @CJ_MCC_NewArray(i8*, i64)

; Function Attrs: argmemonly nounwind
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)* nocapture, i8 addrspace(1)* addrspace(1)* nocapture) #0

; Function Attrs: argmemonly nocallback nofree nounwind willreturn writeonly
declare void @llvm.memset.p1i8.i64(i8 addrspace(1)* nocapture writeonly, i8, i64, i1 immarg) #1

define i64 @foo() gc "cangjie" {
bb0:
  %0 = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @_ZN7default8CrcCheck.ti to i8*), i32 104)
  %1 = call i8 addrspace(1)* @CJ_MCC_NewArray(i8* bitcast (%TypeInfo* @"RawArray<Int64>.ti" to i8*), i64 0)
  %2 = call i8 addrspace(1)* @CJ_MCC_NewArray(i8* bitcast (%TypeInfo* @"RawArray<Int64>.ti" to i8*), i64 50)
  %3 = call i8 addrspace(1)* @CJ_MCC_NewArray(i8* bitcast (%TypeInfo* @"RawArray<Int64>.ti" to i8*), i64 33)
  store i8 50, i8* @_ZN7default20var_1715509008039_60E, align 8
  %4 = load i8, i8* @_ZN7default20var_1715509008039_60E, align 8
  br label %bb1

bb1:
  %phi1 = phi i8 addrspace(1)* [%1, %bb0], [%23, %bb1]
  %phi2 = phi i8 addrspace(1)* [%2, %bb0], [%24, %bb1]
  %phi3 = phi i8 addrspace(1)* [%3, %bb0], [%25, %bb1]
  %phi4 = phi i8 [%4, %bb0], [%5, %bb1]
  %icmp = icmp eq i8 %phi4, 0
  %5 = sub i8 %phi4, 1
  %6 = getelementptr inbounds i8, i8 addrspace(1)* %0, i64 88
  %7 = getelementptr inbounds i8, i8 addrspace(1)* %0, i64 56
  %8 = bitcast i8 addrspace(1)* %7 to i8 addrspace(1)* addrspace(1)*
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %phi1, i8 addrspace(1)* %0, i8 addrspace(1)* addrspace(1)* %8)
  %9 = getelementptr inbounds i8, i8 addrspace(1)* %0, i64 64
  call void @llvm.memset.p1i8.i64(i8 addrspace(1)* noundef align 8 dereferenceable(16) %9, i8 0, i64 16, i1 false)
  %10 = getelementptr inbounds i8, i8 addrspace(1)* %0, i64 8
  %11 = bitcast i8 addrspace(1)* %10 to i8 addrspace(1)* addrspace(1)*
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %phi2, i8 addrspace(1)* %0, i8 addrspace(1)* addrspace(1)* %11)
  %12 = getelementptr inbounds i8, i8 addrspace(1)* %0, i64 16
  store i8 0, i8 addrspace(1)* %12, align 8
  %13 = getelementptr inbounds i8, i8 addrspace(1)* %0, i64 24
  %14 = bitcast i8 addrspace(1)* %13 to i64 addrspace(1)*
  store i64 5000, i64 addrspace(1)* %14, align 8
  %15 = getelementptr inbounds i8, i8 addrspace(1)* %0, i64 80
  %16 = bitcast i8 addrspace(1)* %15 to i64 addrspace(1)*
  store i64 33, i64 addrspace(1)* %16, align 8
  %17 = getelementptr inbounds i8, i8 addrspace(1)* %0, i64 32
  %18 = bitcast i8 addrspace(1)* %17 to i8 addrspace(1)* addrspace(1)*
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %phi3, i8 addrspace(1)* %0, i8 addrspace(1)* addrspace(1)* %18)
  %19 = getelementptr inbounds i8, i8 addrspace(1)* %0, i64 40
  %20 = bitcast i8 addrspace(1)* %19 to i64 addrspace(1)*
  store i64 0, i64 addrspace(1)* %20, align 8
  %21 = getelementptr inbounds i8, i8 addrspace(1)* %0, i64 48
  %22 = bitcast i8 addrspace(1)* %21 to i64 addrspace(1)*
  %23 = call i8 addrspace(1)* @CJ_MCC_NewArray(i8* bitcast (%TypeInfo* @"RawArray<Int64>.ti" to i8*), i64 0)
  %24 = call i8 addrspace(1)* @CJ_MCC_NewArray(i8* bitcast (%TypeInfo* @"RawArray<Int64>.ti" to i8*), i64 50)
  %25 = call i8 addrspace(1)* @CJ_MCC_NewArray(i8* bitcast (%TypeInfo* @"RawArray<Int64>.ti" to i8*), i64 33)
  br i1 %icmp, label %bb2, label %bb1

bb2:
  %26 = load i8, i8* @_ZN7default20var_1715509008039_60E, align 8
  %27 = mul i8 %26, %26
  %28 = zext i8 %27 to i64
  ret i64 %28
}

!0 = !{!"ArrayLayout.Int64"}
!1 = !{!"ObjLayout._ZN7default8CrcCheck"}

attributes #0 = { argmemonly nounwind }
attributes #1 = { argmemonly nocallback nofree nounwind willreturn writeonly }
