; RUN: opt < %s -passes=cj-pea -verify-each -S | FileCheck %s

target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"

%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, i8*, i8*, i8* }
%ObjLayout.Box = type { [56 x i8] }

@Box.ti = global %TypeInfo { i8* null, i8 -128, i8 0, i16 1, i32 56, i8* null, i32 0, i8 8, i8 0, i16 0, i32* null, i8* null, i8* null, i8* null, %TypeInfo* null, i8* null, i8* null, i8* null }, !RelatedType !0

declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare void @escape(i8 addrspace(1)*)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1 immarg)
declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1 immarg)

; Different offsets and the copy back to %a form a cycle in the definition
; graph. Tracing that graph must terminate without dropping the escaping object.
; CHECK-LABEL: define void @cyclic_def(
; CHECK: %h = call i8 addrspace(1)* @CJ_MCC_NewObject(
; CHECK: call void @escape(i8 addrspace(1)* %h)
; CHECK-NEXT: ret void
define void @cyclic_def() gc "cangjie" {
entry:
  %a = alloca [16 x i8]
  %tmp = alloca [16 x i8]
  %a.i8 = bitcast [16 x i8]* %a to i8*
  %tmp.i8 = bitcast [16 x i8]* %tmp to i8*
  %h = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* bitcast (%TypeInfo* @Box.ti to i8*), i32 64)
  %h.field = getelementptr i8, i8 addrspace(1)* %h, i64 40
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %h.field, i8* %a.i8, i64 16, i1 false)
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %a.i8, i8 addrspace(1)* %h.field, i64 16, i1 false)
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %tmp.i8, i8 addrspace(1)* %h.field, i64 16, i1 false)
  call void @escape(i8 addrspace(1)* %h)
  ret void
}

!0 = !{!"ObjLayout.Box"}
