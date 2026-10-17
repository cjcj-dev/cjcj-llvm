; RUN: opt -passes=cj-pea -S %s | FileCheck %s
; A zero-argument ordinary GC pointer call shares the analysis with a real
; allocation. The latter must still become a stack object; the unknown result
; remains escaped, without a guessed allocation type or size. A second allocation
; escapes to keep GCNew nonempty after the preceding EADepth rewrite.

target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, i8*, i8*, i8* }
%Payload = type { i64 }
@plain.ti = global %TypeInfo { i8* null, i8 -128, i8 0, i16 1, i32 8, i8* null, i32 0, i8 8, i8 0, i16 0, i32* null, i8* null, i8* null, i8* null, %TypeInfo* null, i8* null, i8* null, i8* null }, !RelatedType !0

declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare i8 addrspace(1)* @unknown()
declare void @consume(i64)
declare void @escape(i8 addrspace(1)*)
declare i32 @__cj_personality_v0(...)
!0 = !{!"Payload"}

; CHECK-LABEL: define i8 addrspace(1)* @zero_arg_invoke(
; CHECK: alloca { %TypeInfo*, %Payload }
; CHECK: %unknown = invoke i8 addrspace(1)* @unknown()
; CHECK: [[RET:%[^ ]+]] = phi i8 addrspace(1)* [ %unknown, %normal ], [ null, %catch ]
; CHECK: ret i8 addrspace(1)* [[RET]]
; CHECK-NOT: @CJ_MCC_NewObject
; CHECK: store i64 %value,
; CHECK: [[LOADED:%[^ ]+]] = load i64,
; CHECK: call void @consume(i64 [[LOADED]])
; CHECK: [[ESCAPED:%[^ ]+]] = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @plain.ti to i8*), i32 16)
; CHECK: call void @escape(i8 addrspace(1)* [[ESCAPED]])
; CHECK: landingpad { i8*, i32 }
; CHECK: cleanup
define i8 addrspace(1)* @zero_arg_invoke(i64 %value) gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
entry:
  %unknown = invoke i8 addrspace(1)* @unknown() to label %normal unwind label %catch
normal:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @plain.ti to i8*), i32 16)
  %field = getelementptr i8, i8 addrspace(1)* %obj, i64 8
  %slot = bitcast i8 addrspace(1)* %field to i64 addrspace(1)*
  store i64 %value, i64 addrspace(1)* %slot
  %loaded = load i64, i64 addrspace(1)* %slot
  call void @consume(i64 %loaded)
  %escaping = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @plain.ti to i8*), i32 16)
  call void @escape(i8 addrspace(1)* %escaping)
  ret i8 addrspace(1)* %unknown
catch:
  %lp = landingpad { i8*, i32 } cleanup
  ret i8 addrspace(1)* null
}
