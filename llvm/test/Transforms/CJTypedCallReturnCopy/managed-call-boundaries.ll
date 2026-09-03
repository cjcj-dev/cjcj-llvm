; RUN: split-file %s %t
; RUN: not --crash opt -passes='cj-typed-call-return-copy,cj-ir-verifier' -disable-output < %t/allocation.ll 2>&1 | FileCheck %s --check-prefixes=ALLOC,ABORT
; RUN: not --crash opt -passes='cj-typed-call-return-copy,cj-ir-verifier' -disable-output < %t/gcread.ll 2>&1 | FileCheck %s --check-prefixes=GCREAD,ABORT
; RUN: not --crash opt -passes='cj-typed-call-return-copy,cj-ir-verifier' -disable-output < %t/language.ll 2>&1 | FileCheck %s --check-prefixes=LANGUAGE,ABORT
; RUN: not --crash opt -passes='cj-typed-call-return-copy,cj-ir-verifier' -disable-output < %t/indirect.ll 2>&1 | FileCheck %s --check-prefixes=INDIRECT,ABORT

; ALLOC: Bare memcpy/memmove
; ALLOC-NEXT: call void @llvm.memcpy.p0i8.p1i8.i64
; ALLOC: in function keep_managed_allocation
; GCREAD: Bare memcpy/memmove
; GCREAD-NEXT: call void @llvm.memcpy.p0i8.p1i8.i64
; GCREAD: in function keep_managed_gcread
; LANGUAGE: Bare memcpy/memmove
; LANGUAGE-NEXT: call void @llvm.memcpy.p0i8.p1i8.i64
; LANGUAGE: in function keep_managed_language_call
; INDIRECT: Bare memcpy/memmove
; INDIRECT-NEXT: call void @llvm.memcpy.p0i8.p1i8.i64
; INDIRECT: in function keep_managed_indirect_call
; ABORT: LLVM ERROR: Broken function found, compilation aborted

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
