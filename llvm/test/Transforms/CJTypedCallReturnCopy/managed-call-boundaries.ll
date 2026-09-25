; RUN: split-file %s %t
; RUN: opt -passes='cj-typed-call-return-copy,cj-ir-verifier' -disable-output < %t/allocation.ll 2>&1 | FileCheck %s --check-prefix=ALLOC
; RUN: opt -passes='cj-typed-call-return-copy,cj-ir-verifier' -disable-output < %t/gcread.ll 2>&1 | FileCheck %s --check-prefix=GCREAD
; RUN: opt -passes='cj-typed-call-return-copy,cj-ir-verifier' -disable-output < %t/language.ll 2>&1 | FileCheck %s --check-prefix=LANGUAGE
; RUN: opt -passes='cj-typed-call-return-copy,cj-ir-verifier' -disable-output < %t/indirect.ll 2>&1 | FileCheck %s --check-prefix=INDIRECT
; RUN: opt -cj-ir-verifier-mode=report -passes='cj-typed-call-return-copy,cj-ir-verifier' -disable-output < %t/allocation.ll 2>&1 | FileCheck %s --check-prefix=REPORT-ALLOC
; RUN: opt -cj-ir-verifier-mode=report -passes='cj-typed-call-return-copy,cj-ir-verifier' -disable-output < %t/gcread.ll 2>&1 | FileCheck %s --check-prefix=REPORT-GCREAD
; RUN: opt -cj-ir-verifier-mode=report -passes='cj-typed-call-return-copy,cj-ir-verifier' -disable-output < %t/language.ll 2>&1 | FileCheck %s --check-prefix=REPORT-LANGUAGE
; RUN: opt -cj-ir-verifier-mode=report -passes='cj-typed-call-return-copy,cj-ir-verifier' -disable-output < %t/indirect.ll 2>&1 | FileCheck %s --check-prefix=REPORT-INDIRECT

; ALLOC: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]
; ALLOC-NEXT: call void @llvm.memcpy.p0i8.p1i8.i64
; ALLOC: in function keep_managed_allocation
; ALLOC-NOT: LLVM ERROR
; GCREAD: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]
; GCREAD-NEXT: call void @llvm.memcpy.p0i8.p1i8.i64
; GCREAD: in function keep_managed_gcread
; GCREAD-NOT: LLVM ERROR
; LANGUAGE: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]
; LANGUAGE-NEXT: call void @llvm.memcpy.p0i8.p1i8.i64
; LANGUAGE: in function keep_managed_language_call
; LANGUAGE-NOT: LLVM ERROR
; INDIRECT: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]
; INDIRECT-NEXT: call void @llvm.memcpy.p0i8.p1i8.i64
; INDIRECT: in function keep_managed_indirect_call
; INDIRECT-NOT: LLVM ERROR
; REPORT-ALLOC: keep_managed_allocation{{[[:space:]]}}Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]{{[[:space:]]}}memcpy
; REPORT-ALLOC-NOT: LLVM ERROR
; REPORT-ALLOC-NOT: in function
; REPORT-GCREAD: keep_managed_gcread{{[[:space:]]}}Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]{{[[:space:]]}}memcpy
; REPORT-GCREAD-NOT: LLVM ERROR
; REPORT-GCREAD-NOT: in function
; REPORT-LANGUAGE: keep_managed_language_call{{[[:space:]]}}Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]{{[[:space:]]}}memcpy
; REPORT-LANGUAGE-NOT: LLVM ERROR
; REPORT-LANGUAGE-NOT: in function
; REPORT-INDIRECT: keep_managed_indirect_call{{[[:space:]]}}Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]{{[[:space:]]}}memcpy
; REPORT-INDIRECT-NOT: LLVM ERROR
; REPORT-INDIRECT-NOT: in function

;--- allocation.ll
%Ref = type { i8 addrspace(1)*, i64 }
%Plain = type { i8*, i64 }
define void @keep_managed_allocation(i8* %typeinfo) gc "cangjie" {
entry:
  %dst = alloca %Plain, align 8
  %call = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* %typeinfo, i32 16)
  %typed = bitcast i8 addrspace(1)* %call to %Ref addrspace(1)*
  %zero = getelementptr %Ref, %Ref addrspace(1)* %typed, i64 0
  %dst.bytes = bitcast %Plain* %dst to i8*
  %src.bytes = bitcast %Ref addrspace(1)* %zero to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst.bytes, i8 addrspace(1)* %src.bytes, i64 16, i1 false)
  ret void
}
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)

;--- gcread.ll
%Ref = type { i8 addrspace(1)*, i64 }
%Plain = type { i8*, i64 }
define void @keep_managed_gcread(i8 addrspace(1)** %slot) gc "cangjie" {
entry:
  %dst = alloca %Plain, align 8
  %call = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** %slot)
  %typed = bitcast i8 addrspace(1)* %call to %Ref addrspace(1)*
  %zero = getelementptr %Ref, %Ref addrspace(1)* %typed, i64 0
  %dst.bytes = bitcast %Plain* %dst to i8*
  %src.bytes = bitcast %Ref addrspace(1)* %zero to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst.bytes, i8 addrspace(1)* %src.bytes, i64 16, i1 false)
  ret void
}
declare i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)**)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)

;--- language.ll
%Ref = type { i8 addrspace(1)*, i64 }
%Plain = type { i8*, i64 }
define void @keep_managed_language_call() gc "cangjie" {
entry:
  %dst = alloca %Plain, align 8
  %call = call i8 addrspace(1)* @managed_language()
  %typed = bitcast i8 addrspace(1)* %call to %Ref addrspace(1)*
  %zero = getelementptr %Ref, %Ref addrspace(1)* %typed, i64 0
  %dst.bytes = bitcast %Plain* %dst to i8*
  %src.bytes = bitcast %Ref addrspace(1)* %zero to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst.bytes, i8 addrspace(1)* %src.bytes, i64 16, i1 false)
  ret void
}
declare i8 addrspace(1)* @managed_language()
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)

;--- indirect.ll
%Ref = type { i8 addrspace(1)*, i64 }
%Plain = type { i8*, i64 }
define void @keep_managed_indirect_call(i8 addrspace(1)* ()* %callee) gc "cangjie" {
entry:
  %dst = alloca %Plain, align 8
  %call = call i8 addrspace(1)* %callee()
  %typed = bitcast i8 addrspace(1)* %call to %Ref addrspace(1)*
  %zero = getelementptr %Ref, %Ref addrspace(1)* %typed, i64 0
  %dst.bytes = bitcast %Plain* %dst to i8*
  %src.bytes = bitcast %Ref addrspace(1)* %zero to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst.bytes, i8 addrspace(1)* %src.bytes, i64 16, i1 false)
  ret void
}
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
