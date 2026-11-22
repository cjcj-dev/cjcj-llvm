; RUN: opt < %s '-passes=cj-pea' -S | FileCheck %s
; REQUIRES: arm-registered-target
; ARM32: the native object header is 8 bytes, so the payload is addressed at
; +8 and a stack copy needs 8 + sizeof(Layout) bytes. For a layout with only
; 4-byte aligned members ({ i32, i32 }) the natural { TypeInfo*, Layout }
; struct puts the payload at +4 and is 12 bytes, 4 short of the 16-byte object
; (and of the +8..+16 clear). Such an object stays on the heap. A layout with
; an i64 member is 8-byte aligned (payload at +8, 16 bytes) and is still
; stack allocated.

target datalayout = "e-m:e-p:32:32-Fi8-i64:64-v128:64:128-a:0:32-n32-S64"
target triple = "armv7a-unknown-linux-gnueabihf"

; CHECK-LABEL: @low_align(
; CHECK-NOT: alloca
; CHECK: call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @Pair.ti to i8*), i32 16)
; CHECK-NOT: memset
; CHECK: ret i32

; CHECK-LABEL: @wide_align(
; CHECK: [[OBJ:%[0-9]+]] = alloca { %TypeInfo*, %ObjLayout.Wide }, align 8
; CHECK: [[P:%[0-9]+]] = getelementptr inbounds i8, i8* %{{[0-9]+}}, i32 8
; CHECK-NEXT: call void @llvm.memset.p0i8.i64(i8* [[P]], i8 0, i64 8, i1 false)
; CHECK-NOT: @CJ_MCC_NewObject
; CHECK: ret i64

%BitMap = type { i32, [0 x i8] }
%ObjLayout.Pair = type { i32, i32 }
%ObjLayout.Wide = type { i64 }
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i32*, i8*, i8*, i8*, %TypeInfo*, i8*, i8* }

@Pair.name = internal global [5 x i8] c"Pair\00", align 1
@Wide.name = internal global [5 x i8] c"Wide\00", align 1
@"std.core$Object.ti" = external global %TypeInfo
@Pair.ti = internal global %TypeInfo { i8* getelementptr inbounds ([5 x i8], [5 x i8]* @Pair.name, i32 0, i32 0), i8 -128, i8 0, i16 2, i32 8, %BitMap* null, i32 0, i8 4, i8 0, i32* null, i8* null, i8* null, i8* null, %TypeInfo* @"std.core$Object.ti", i8* null, i8* null }, !RelatedType !0
@Wide.ti = internal global %TypeInfo { i8* getelementptr inbounds ([5 x i8], [5 x i8]* @Wide.name, i32 0, i32 0), i8 -128, i8 0, i16 1, i32 8, %BitMap* null, i32 0, i8 8, i8 0, i32* null, i8* null, i8* null, i8* null, %TypeInfo* @"std.core$Object.ti", i8* null, i8* null }, !RelatedType !1

declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)

define i32 @low_align(i32 %a, i32 %b) gc "cangjie" {
entry:
  %0 = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @Pair.ti to i8*), i32 16)
  %1 = getelementptr inbounds i8, i8 addrspace(1)* %0, i64 8
  %2 = bitcast i8 addrspace(1)* %1 to i32 addrspace(1)*
  store i32 %a, i32 addrspace(1)* %2, align 4
  %3 = getelementptr inbounds i8, i8 addrspace(1)* %0, i64 12
  %4 = bitcast i8 addrspace(1)* %3 to i32 addrspace(1)*
  store i32 %b, i32 addrspace(1)* %4, align 4
  %5 = load i32, i32 addrspace(1)* %2, align 4
  %6 = load i32, i32 addrspace(1)* %4, align 4
  %7 = add i32 %5, %6
  ret i32 %7
}

define i64 @wide_align(i64 %a) gc "cangjie" {
entry:
  %0 = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @Wide.ti to i8*), i32 16)
  %1 = getelementptr inbounds i8, i8 addrspace(1)* %0, i64 8
  %2 = bitcast i8 addrspace(1)* %1 to i64 addrspace(1)*
  store i64 %a, i64 addrspace(1)* %2, align 8
  %3 = load i64, i64 addrspace(1)* %2, align 8
  ret i64 %3
}

!0 = !{!"ObjLayout.Pair"}
!1 = !{!"ObjLayout.Wide"}
