; RUN: opt -cj-rewrite-statepoint -sroa -S < %s | FileCheck %s
; RUN: opt -passes=cj-rewrite-statepoint,sroa -S < %s | FileCheck %s

%record = type { i64, i8 addrspace(1)* }

declare void @g0() #0 gc "cangjie"
declare void @g1(%record addrspace(1)* %arg1, i8 addrspace(1)* %arg0) #0 gc "cangjie"

define %record @foo(%record addrspace(1)* %arg2, i8 addrspace(1)* %arg1, %record %arg0) #0 gc "cangjie" {
; CHECK:  entry:
; CHECK-NEXT:  %.sroa.0.sroa.0 = alloca i8, align 8
; CHECK-NEXT:  %arg0.fca.0.extract = extractvalue %record %arg0, 0
; CHECK-NEXT:  %.sroa.0.0.extract.trunc = trunc i64 %arg0.fca.0.extract to i8
; CHECK-NEXT:  store i8 %.sroa.0.0.extract.trunc, i8* %.sroa.0.sroa.0, align 8
; CHECK-NEXT:  %.sroa.5.0.extract.shift = lshr i64 %arg0.fca.0.extract, 8
; CHECK-NEXT:  %.sroa.5.0.extract.trunc = trunc i64 %.sroa.5.0.extract.shift to i56
; CHECK-NEXT:  %arg0.fca.1.extract = extractvalue %record %arg0, 1
; CHECK-NEXT:  %.sroa.0.sroa.0.0..sroa.0.sroa.0.0..sroa.0.0.9 = load i8, i8* %.sroa.0.sroa.0, align 8
; CHECK-NEXT:  %.sroa.5.0.insert.ext = zext i56 %.sroa.5.0.extract.trunc to i64
; CHECK-NEXT:  %.sroa.5.0.insert.shift = shl i64 %.sroa.5.0.insert.ext, 8
; CHECK-NEXT:  %.sroa.5.0.insert.mask = and i64 undef, 255
; CHECK-NEXT:  %.sroa.5.0.insert.insert = or i64 %.sroa.5.0.insert.mask, %.sroa.5.0.insert.shift
; CHECK-NEXT:  %.sroa.0.0.insert.ext = zext i8 %.sroa.0.sroa.0.0..sroa.0.sroa.0.0..sroa.0.0.9 to i64
; CHECK-NEXT:  %.sroa.0.0.insert.mask = and i64 %.sroa.5.0.insert.insert, -256
; CHECK-NEXT:  %.sroa.0.0.insert.insert = or i64 %.sroa.0.0.insert.mask, %.sroa.0.0.insert.ext
; CHECK-NEXT:  %icmpeq = icmp eq i64 %.sroa.0.0.insert.insert, 1
;
entry:
  %0 = alloca %record
  store %record %arg0, %record* %0
  %1 = getelementptr inbounds %record, %record* %0, i32 0, i32 0
  %2 = load i64, i64* %1
  %icmpeq = icmp eq i64 %2, 1
  br i1 %icmpeq, label %tmp1, label %tmp2

; CHECK:  tmp1:
; CHECK-NEXT:  %.sroa.0.sroa.0.0..sroa.0.sroa.0.0..sroa.0.0..fca.0.load = load i8, i8* %.sroa.0.sroa.0, align 8
; CHECK-NEXT:  [[TMP1_EXT:%.*]] = zext i56 %.sroa.5.0.extract.trunc to i64
; CHECK-NEXT:  [[TMP1_SHIFT:%.*]] = shl i64 [[TMP1_EXT]], 8
; CHECK-NEXT:  [[TMP1_MASK:%.*]] = and i64 undef, 255
; CHECK-NEXT:  [[TMP1_INSERT:%.*]] = or i64 [[TMP1_MASK]], [[TMP1_SHIFT]]
; CHECK-NEXT:  [[TMP1_LOW_EXT:%.*]] = zext i8 %.sroa.0.sroa.0.0..sroa.0.sroa.0.0..sroa.0.0..fca.0.load to i64
; CHECK-NEXT:  [[TMP1_LOW_MASK:%.*]] = and i64 [[TMP1_INSERT]], -256
; CHECK-NEXT:  [[TMP1_LOW_INSERT:%.*]] = or i64 [[TMP1_LOW_MASK]], [[TMP1_LOW_EXT]]
; CHECK-NEXT:  %.fca.0.insert = insertvalue %record poison, i64 [[TMP1_LOW_INSERT]], 0
; CHECK-NEXT:  %.fca.1.insert = insertvalue %record %.fca.0.insert, i8 addrspace(1)* %arg0.fca.1.extract, 1
; CHECK-NEXT:  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, void ()* @g0, i32 0, i32 0)
;
tmp1:
  %3 = load %record, %record* %0
  call void @g0()
  br label %tmpend

; CHECK:  tmp2:
; CHECK-NEXT:  [[TMP2_CAST:%.*]] = bitcast i8* %.sroa.0.sroa.0 to i1*
; CHECK-NEXT:  %.sroa.0.sroa.0.0..sroa.0.sroa.0.0..sroa.0.0. = load i1, i1* [[TMP2_CAST]], align 8
; CHECK-NEXT:  %token2 = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, void (%record addrspace(1)*, i8 addrspace(1)*)* @g1, i32 2, i32 0, %record addrspace(1)* %arg2, i8 addrspace(1)* null) [ "gc-live"(%record %arg0) ]
;
tmp2:
  %4 = bitcast %record* %0 to i1*
  %5 = load i1, i1* %4
  call void @g1(%record addrspace(1)* %arg2, i8 addrspace(1)* null)
  ret %record %arg0

; CHECK:  tmpend:
; CHECK-NEXT:  %.sroa.0.sroa.0.0..sroa.0.sroa.0.0..sroa.0.0..fca.0.load4 = load i8, i8* %.sroa.0.sroa.0, align 8
; CHECK-NEXT:  [[END_EXT:%.*]] = zext i56 %.sroa.5.0.extract.trunc to i64
; CHECK-NEXT:  [[END_SHIFT:%.*]] = shl i64 [[END_EXT]], 8
; CHECK-NEXT:  [[END_MASK:%.*]] = and i64 undef, 255
; CHECK-NEXT:  [[END_INSERT:%.*]] = or i64 [[END_MASK]], [[END_SHIFT]]
; CHECK-NEXT:  [[END_LOW_EXT:%.*]] = zext i8 %.sroa.0.sroa.0.0..sroa.0.sroa.0.0..sroa.0.0..fca.0.load4 to i64
; CHECK-NEXT:  [[END_LOW_MASK:%.*]] = and i64 [[END_INSERT]], -256
; CHECK-NEXT:  [[END_LOW_INSERT:%.*]] = or i64 [[END_LOW_MASK]], [[END_LOW_EXT]]
; CHECK-NEXT:  %.fca.0.insert5 = insertvalue %record poison, i64 [[END_LOW_INSERT]], 0
; CHECK-NEXT:  %.fca.1.insert8 = insertvalue %record %.fca.0.insert5, i8 addrspace(1)* %arg0.fca.1.extract, 1
;
tmpend:
  %6 = load %record, %record* %0
  ret %record %6
}

attributes #0 = { "record_mut" }
