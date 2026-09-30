; RUN: opt < %s -mtriple=x86_64-unknown-linux-gnu -passes=cj-pea -S | FileCheck %s --implicit-check-not='alloca '
; RUN: opt < %s -mtriple=aarch64-unknown-linux-gnu -passes=cj-pea -S | FileCheck %s --implicit-check-not='alloca '

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

; CHECK-LABEL: @final_call(
; CHECK: call {{.*}}@CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @final.ti
; CHECK: ret i64
define i64 @final_call(i64 %value) gc "cangjie" {
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @final.ti to i8*), i32 16)
  %field = getelementptr i8, i8 addrspace(1)* %obj, i64 8
  %slot = bitcast i8 addrspace(1)* %field to i64 addrspace(1)*
  store i64 %value, i64 addrspace(1)* %slot
  %loaded = load i64, i64 addrspace(1)* %slot
  ret i64 %loaded
}

; CHECK-LABEL: @generic_call(
; CHECK: call {{.*}}@CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @generic.ti
; CHECK: ret i64
define i64 @generic_call(i64 %value) gc "cangjie" {
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @generic.ti to i8*), i32 16)
  %field = getelementptr i8, i8 addrspace(1)* %obj, i64 8
  %slot = bitcast i8 addrspace(1)* %field to i64 addrspace(1)*
  store i64 %value, i64 addrspace(1)* %slot
  %loaded = load i64, i64 addrspace(1)* %slot
  ret i64 %loaded
}

; CHECK-LABEL: @attribute_call(
; CHECK: call {{.*}}@CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @attribute.ti
; CHECK: ret i64
define i64 @attribute_call(i64 %value) gc "cangjie" {
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @attribute.ti to i8*), i32 16)
  %field = getelementptr i8, i8 addrspace(1)* %obj, i64 8
  %slot = bitcast i8 addrspace(1)* %field to i64 addrspace(1)*
  store i64 %value, i64 addrspace(1)* %slot
  %loaded = load i64, i64 addrspace(1)* %slot
  ret i64 %loaded
}

; CHECK-LABEL: @external_call(
; CHECK: call {{.*}}@CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @external.ti
; CHECK: ret i64
define i64 @external_call(i64 %value) gc "cangjie" {
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @external.ti to i8*), i32 16)
  %field = getelementptr i8, i8 addrspace(1)* %obj, i64 8
  %slot = bitcast i8 addrspace(1)* %field to i64 addrspace(1)*
  store i64 %value, i64 addrspace(1)* %slot
  %loaded = load i64, i64 addrspace(1)* %slot
  ret i64 %loaded
}

; CHECK-LABEL: @final_invoke(
; CHECK: invoke {{.*}}@CJ_MCC_NewObject(
; CHECK: unwind label %unwind
; CHECK: ret i64
; CHECK: resume
define i64 @final_invoke(i64 %value) gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
entry:
  %obj = invoke i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @final.ti to i8*), i32 16) to label %normal unwind label %unwind
normal:
  %field = getelementptr i8, i8 addrspace(1)* %obj, i64 8
  %slot = bitcast i8 addrspace(1)* %field to i64 addrspace(1)*
  store i64 %value, i64 addrspace(1)* %slot
  %loaded = load i64, i64 addrspace(1)* %slot
  ret i64 %loaded
unwind:
  %exception = landingpad { i8*, i32 } cleanup
  resume { i8*, i32 } %exception
}

; CHECK-LABEL: @retained_child(
; CHECK: call {{.*}}@CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @holder.ti
; CHECK: call {{.*}}@CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @plain.ti
; CHECK: store i8 addrspace(1)* %child
; CHECK: ret void
define void @retained_child() gc "cangjie" {
  %holder = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @holder.ti to i8*), i32 16)
  %child = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @plain.ti to i8*), i32 16)
  %field = getelementptr i8, i8 addrspace(1)* %holder, i64 8
  %slot = bitcast i8 addrspace(1)* %field to i8 addrspace(1)* addrspace(1)*
  store i8 addrspace(1)* %child, i8 addrspace(1)* addrspace(1)* %slot
  ret void
}
