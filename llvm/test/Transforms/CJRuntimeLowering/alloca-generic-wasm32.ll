; RUN: opt -passes=cj-runtime-lowering -S < %s | FileCheck %s
; REQUIRES: webassembly-registered-target
; A non-escaping alloca.generic box on wasm32 must keep the heap box layout of
; CJ_MCC_NewObject: the payload follows the 4-byte TypeInfo pointer (the frontend
; addresses it as `getelementptr i8*, ..., i32 1`, i.e. +4). The arm32 i32
; padding would move it to +8.

target datalayout = "e-m:e-p:32:32-p10:8:8-p20:8:8-i64:64-n32:64-S128-ni:1:10:20"
target triple = "wasm32-unknown-wasi"

%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }
@Int64.ti = external global %TypeInfo, !RelatedType !0 #0

declare i8 addrspace(1)* @llvm.cj.alloca.generic(i8*, i32)
declare void @koo(i8 addrspace(1)* noalias sret(i8), %TypeInfo*) gc "cangjie"

; CHECK-LABEL: @box_int64(
; CHECK: %0 = alloca <{ %TypeInfo*, i64 }>, align 8
; CHECK-NOT: alloca { %TypeInfo*, i32, i64 }
; CHECK: store i8* bitcast (%TypeInfo* @Int64.ti to i8*), i8** %{{[0-9]+}}, align 4
define i64 @box_int64(i64 %x) gc "cangjie" {
bb0:
  %0 = call i8 addrspace(1)* @llvm.cj.alloca.generic(i8* bitcast (%TypeInfo* @Int64.ti to i8*), i32 8)
  %1 = bitcast i8 addrspace(1)* %0 to i8* addrspace(1)*
  %ti.payload = getelementptr i8*, i8* addrspace(1)* %1, i32 1
  %2 = bitcast i8* addrspace(1)* %ti.payload to i64 addrspace(1)*
  store i64 %x, i64 addrspace(1)* %2, align 4
  call void @koo(i8 addrspace(1)* noalias sret(i8) %0, %TypeInfo* @Int64.ti)
  ret i64 %x
}

attributes #0 = { "CFileKlass" "NotModifiableClass" }

!0 = !{!"Int64.Type"}
