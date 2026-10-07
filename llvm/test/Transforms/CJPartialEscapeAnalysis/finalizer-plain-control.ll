; RUN: opt < %s -mtriple=x86_64-unknown-linux-gnu -passes=cj-pea -S | FileCheck %s
; RUN: opt < %s -mtriple=aarch64-unknown-linux-gnu -passes=cj-pea -S | FileCheck %s
; RUN: opt < %s -mtriple=x86_64-unknown-linux-gnu -passes=cj-pea -cj-disable-partial-ea -S | FileCheck %s
; RUN: opt < %s -mtriple=aarch64-unknown-linux-gnu -passes=cj-pea -cj-disable-partial-ea -S | FileCheck %s

%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, i8*, i8*, i8* }
%Payload = type { i64 }
%Holder = type { i8 addrspace(1)* }
@plain.ti = global %TypeInfo { i8* null, i8 -128, i8 0, i16 1, i32 8, i8* null, i32 0, i8 8, i8 0, i16 0, i32* null, i8* null, i8* null, i8* null, %TypeInfo* null, i8* null, i8* null, i8* null }, !RelatedType !0
@final.ti = global %TypeInfo { i8* null, i8 -128, i8 2, i16 1, i32 8, i8* null, i32 0, i8 8, i8 0, i16 0, i32* null, i8* null, i8* null, i8* null, %TypeInfo* null, i8* null, i8* null, i8* null }, !RelatedType !0
@generic.ti = global %TypeInfo { i8* null, i8 -128, i8 2, i16 1, i32 8, i8* null, i32 0, i8 8, i8 1, i16 0, i32* null, i8* null, i8* null, i8* null, %TypeInfo* null, i8* null, i8* null, i8* null }, !RelatedType !0
@attribute.ti = global %TypeInfo { i8* null, i8 -128, i8 0, i16 1, i32 8, i8* null, i32 0, i8 8, i8 0, i16 0, i32* null, i8* null, i8* null, i8* null, %TypeInfo* null, i8* null, i8* null, i8* null }, !RelatedType !0 #0
@holder.ti = global %TypeInfo { i8* null, i8 -128, i8 3, i16 1, i32 8, i8* null, i32 0, i8 8, i8 0, i16 0, i32* null, i8* null, i8* null, i8* null, %TypeInfo* null, i8* null, i8* null, i8* null }, !RelatedType !1
@external.ti = external global %TypeInfo, !RelatedType !0 #0
declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare i32 @__cj_personality_v0(...)
attributes #0 = { "HasFinalizer" }
!0 = !{!"Payload"}
!1 = !{!"Holder"}

; CHECK-LABEL: @plain_call(
; CHECK: alloca { %TypeInfo*, %Payload }
; CHECK-NOT: @CJ_MCC_NewObject
; CHECK: ret i64
define i64 @plain_call(i64 %value) gc "cangjie" {
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @plain.ti to i8*), i32 16)
  %field = getelementptr i8, i8 addrspace(1)* %obj, i64 8
  %slot = bitcast i8 addrspace(1)* %field to i64 addrspace(1)*
  store i64 %value, i64 addrspace(1)* %slot
  %loaded = load i64, i64 addrspace(1)* %slot
  ret i64 %loaded
}
