; RUN: opt '-passes=cj-pea' -S < %s | FileCheck %s

; A method that returns `this` and also stores it into a heap-escaping closure
; must summarize `this` as globally escaped. Otherwise the caller stack
; allocates the receiver and the heap closure holds a stack address
; (std.unittest Measurements.calculateMean).

%Unit.Type = type { i8 }

declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)

%BitMap = type { i32, [0 x i8] }
%ObjLayout.Object = type { %TypeInfo* }
%"ObjLayout._ZN11std$FS$core6ObjectE" = type { %ObjLayout.Object }
%"record._ZN7default11std$FS$core5ArrayIN_ZN11std$FS$core6OptionIC_ZN7default5HumanEEE" = type { i8 addrspace(1)*, i64, i64 }
%ObjLayout._ZN7default5HumanE = type { i8 addrspace(1)* }
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i32*, i8*, i8*, i8*, %TypeInfo*, i8*, i8* }

@"std.core$Object.ti" = external global %TypeInfo
@_ZN7default5HumanE.ti = weak_odr global %TypeInfo {i8* getelementptr inbounds ([14 x i8], [14 x i8]* @"default$Human.name", i32 0, i32 0), i8 -128, i8 0, i16 2, i32 16, %BitMap* null, i32 0, i8 8, i8 0, i32* getelementptr inbounds ([1 x i32], [1 x i32]* @"default$Human.ti.offsets", i32 0, i32 0), i8* null, i8* null, i8* bitcast ([1 x %TypeInfo*]* @"default$Human.ti.fields" to i8*), %TypeInfo* @"std.core$Object.ti", i8* null, i8* bitcast ([1 x i8*]* @"default$Human.fieldNames" to i8*)}, !RelatedType !0
@"default$Human.name" = internal global [14 x i8] c"default$Human\00", align 1
@"default$Human.ti.offsets" = internal global [1 x i32] [i32 0]
@"default$Human.ti.fields" = internal global [1 x %TypeInfo*] [%TypeInfo* @"std.core$Object.ti"]
@"default$Human.fieldNames" = internal global [1 x i8*] [i8* getelementptr inbounds ([3 x i8], [3 x i8]* @"default$Human.field.1.name", i32 0, i32 0)]
@"default$Human.field.1.name" = internal global [3 x i8] c"aa\00", align 1
declare void @external_sink(i8 addrspace(1)*)

define i8 addrspace(1)* @capture_and_return(i8 addrspace(1)* %this) gc "cangjie" {
entry:
  %env = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @_ZN7default5HumanE.ti to i8*), i32 16)
  %slot = getelementptr inbounds i8, i8 addrspace(1)* %env, i64 8
  %slotp = bitcast i8 addrspace(1)* %slot to i8 addrspace(1)* addrspace(1)*
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %this, i8 addrspace(1)* %env, i8 addrspace(1)* addrspace(1)* %slotp)
  call void @external_sink(i8 addrspace(1)* %env)
  ret i8 addrspace(1)* %this
}

define i8 addrspace(1)* @return_only(i8 addrspace(1)* %this) gc "cangjie" {
entry:
  ret i8 addrspace(1)* %this
}

define void @caller_capture() gc "cangjie" {
; CHECK-LABEL: @caller_capture(
; CHECK-NOT: alloca
; CHECK: call i8 addrspace(1)* @CJ_MCC_NewObject
; CHECK: call i8 addrspace(1)* @capture_and_return
entry:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @_ZN7default5HumanE.ti to i8*), i32 16)
  %r = call i8 addrspace(1)* @capture_and_return(i8 addrspace(1)* %obj)
  ret void
}

; Legal non-escaping receiver: returning `this` alone keeps stack allocation.
define void @caller_return_only() gc "cangjie" {
; CHECK-LABEL: @caller_return_only(
; CHECK: alloca { %TypeInfo*, %ObjLayout._ZN7default5HumanE }
; CHECK-NOT: @CJ_MCC_NewObject
; CHECK: ret void
entry:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @_ZN7default5HumanE.ti to i8*), i32 16)
  %r = call i8 addrspace(1)* @return_only(i8 addrspace(1)* %obj)
  ret void
}

!0 = !{!"ObjLayout._ZN7default5HumanE"}
