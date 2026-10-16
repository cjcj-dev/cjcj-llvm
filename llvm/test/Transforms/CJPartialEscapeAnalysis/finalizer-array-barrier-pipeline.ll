; RUN: opt -passes=cj-ir-verifier -disable-output < %s
; RUN: opt -passes=cj-pea -S < %s | FileCheck %s --check-prefix=PEA --implicit-check-not='~init' --implicit-check-not=cj.finalizer.unwind
; RUN: opt -passes='cgscc(cj-pea),cj-rewrite-statepoint' -S < %s > %t
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 -enable-gc-fast-path=false -print-after=cj-barrier-lowering -o /dev/null < %t 2>&1 | FileCheck %s --check-prefix=BARRIER
; RUN: llc --cangjie-pipeline -mtriple=aarch64 -O2 -enable-gc-fast-path=false -print-after=cj-barrier-lowering -o /dev/null < %t 2>&1 | FileCheck %s --check-prefix=BARRIER

target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"

%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, i8*, i8*, i8* }
%Holder = type { i8 addrspace(1)* }
%Payload = type { i64 }
@final.ti = global %TypeInfo { i8* null, i8 -128, i8 3, i16 1, i32 8, i8* null, i32 0, i8 8, i8 0, i16 0, i32* null, i8* null, i8* null, i8* null, %TypeInfo* null, i8* null, i8* null, i8* null }, !RelatedType !0
@plain.ti = global %TypeInfo zeroinitializer, !RelatedType !1
@array.ti = external global %TypeInfo

declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare i8 addrspace(1)* @CJ_MCC_NewObjArray(i8*, i64, i64)
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)
declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)

; PEA-LABEL: define i8 addrspace(1)* @finalizer_array_load(
; PEA-NOT: alloca
; PEA: %holder = call {{.*}}@CJ_MCC_NewObject(
; PEA: %array = call {{.*}}@CJ_MCC_NewObjArray(
; PEA: @llvm.cj.gcwrite.ref(i8 addrspace(1)* %array,
; PEA-NOT: alloca
; PEA: ret i8 addrspace(1)*
; BARRIER-LABEL: define i8 addrspace(1)* @finalizer_array_load(
; BARRIER: call {{.*}}@CJ_MCC_LoadBarrierOnOopFieldPreloaded({{.*}}%array.slot)
; BARRIER: ret i8 addrspace(1)*
define i8 addrspace(1)* @finalizer_array_load() gc "cangjie" {
  %holder = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @final.ti to i8*), i32 16)
  %array = call i8 addrspace(1)* @CJ_MCC_NewObjArray(i8* bitcast (%TypeInfo* @array.ti to i8*), i64 8191, i64 poison)
  %holder.field = getelementptr i8, i8 addrspace(1)* %holder, i64 8
  %holder.slot = bitcast i8 addrspace(1)* %holder.field to i8 addrspace(1)* addrspace(1)*
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %array, i8 addrspace(1)* %holder, i8 addrspace(1)* addrspace(1)* %holder.slot, i32 1)
  %array.field = getelementptr inbounds i8, i8 addrspace(1)* %array, i64 65536
  %array.slot = bitcast i8 addrspace(1)* %array.field to i8 addrspace(1)* addrspace(1)*
  %loaded = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %array, i8 addrspace(1)* addrspace(1)* %array.slot)
  ret i8 addrspace(1)* %loaded
}

; PEA-LABEL: define void @finalizer_array_store(
; PEA-NOT: alloca
; PEA: %holder = call {{.*}}@CJ_MCC_NewObject(
; PEA: %array = call {{.*}}@CJ_MCC_NewObjArray(
; PEA: @llvm.cj.gcwrite.ref(i8 addrspace(1)* %array,
; PEA-NOT: alloca
; PEA: ret void
; BARRIER-LABEL: define void @finalizer_array_store(
; BARRIER: call void @CJ_MCC_StoreBarrierOnHeapField(i8 addrspace(1)* addrspace(1)* %array.slot)
; BARRIER: ret void
define void @finalizer_array_store(i8 addrspace(1)* %value) gc "cangjie" {
  %holder = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @final.ti to i8*), i32 16)
  %array = call i8 addrspace(1)* @CJ_MCC_NewObjArray(i8* bitcast (%TypeInfo* @array.ti to i8*), i64 8191, i64 poison)
  %holder.field = getelementptr i8, i8 addrspace(1)* %holder, i64 8
  %holder.slot = bitcast i8 addrspace(1)* %holder.field to i8 addrspace(1)* addrspace(1)*
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %array, i8 addrspace(1)* %holder, i8 addrspace(1)* addrspace(1)* %holder.slot, i32 1)
  %array.field = getelementptr inbounds i8, i8 addrspace(1)* %array, i64 65536
  %array.slot = bitcast i8 addrspace(1)* %array.field to i8 addrspace(1)* addrspace(1)*
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %array, i8 addrspace(1)* addrspace(1)* %array.slot, i32 1)
  ret void
}

; PEA-LABEL: define i64 @plain_control(
; PEA: alloca { %TypeInfo*, %Payload }
; PEA-NOT: @CJ_MCC_NewObject
; PEA: ret i64
define i64 @plain_control(i64 %value) gc "cangjie" {
  %object = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @plain.ti to i8*), i32 16)
  %field = getelementptr i8, i8 addrspace(1)* %object, i64 8
  %slot = bitcast i8 addrspace(1)* %field to i64 addrspace(1)*
  store i64 %value, i64 addrspace(1)* %slot
  %loaded = load i64, i64 addrspace(1)* %slot
  ret i64 %loaded
}

!0 = !{!"Holder"}
!1 = !{!"Payload"}
