; RUN: split-file %s %t
; RUN: opt -passes=cj-boxed-value-barrier -S < %t/rewrite.ll | FileCheck %s --check-prefix=REWRITE
; RUN: opt -passes=cj-boxed-value-barrier -S < %t/keep-non-as1.ll | FileCheck %s --check-prefix=NON-AS1
; RUN: not --crash opt -passes='cj-boxed-value-barrier,cj-ir-verifier' -disable-output < %t/reject-size-mismatch.ll 2>&1 | FileCheck %s --check-prefixes=MISMATCH,ABORT

; REWRITE-LABEL: define i8 addrspace(1)* @rewrite_alloca_generic_payload(
; REWRITE: %object = call i8 addrspace(1)* @llvm.cj.alloca.generic(i8* %type.info, i32 %size)
; REWRITE-NEXT: %object.fields = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
; REWRITE-NEXT: %payload.slot = getelementptr i8*, i8* addrspace(1)* %object.fields, i32 1
; REWRITE-NEXT: %payload = bitcast i8* addrspace(1)* %payload.slot to i8 addrspace(1)*
; REWRITE-NEXT: call void @llvm.cj.gcwrite.generic.payload(i8 addrspace(1)* %object, i8* %source, i32 %size)
; REWRITE-NOT: call void @llvm.memcpy

; NON-AS1-LABEL: define void @keep_non_as1_destination(
; NON-AS1: call void @llvm.memcpy.p0i8.p0i8.i32
; NON-AS1-NOT: call void @llvm.cj.gcwrite.generic.payload

; MISMATCH: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance.
; MISMATCH-NEXT: call void @llvm.memcpy.p1i8.p0i8.i32
; MISMATCH: in function reject_size_mismatch
; ABORT: LLVM ERROR: Broken function found, compilation aborted

;--- rewrite.ll
define i8 addrspace(1)* @rewrite_alloca_generic_payload(
    i8* %type.info, i8* %source, i32 %size) gc "cangjie" {
entry:
  %object = call i8 addrspace(1)* @llvm.cj.alloca.generic(i8* %type.info,
                                                          i32 %size)
  %object.fields = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.slot = getelementptr i8*, i8* addrspace(1)* %object.fields, i32 1
  %payload = bitcast i8* addrspace(1)* %payload.slot to i8 addrspace(1)*
  call void @llvm.memcpy.p1i8.p0i8.i32(i8 addrspace(1)* %payload,
                                       i8* %source, i32 %size, i1 false)
  ret i8 addrspace(1)* %object
}

declare i8 addrspace(1)* @llvm.cj.alloca.generic(i8*, i32)
declare void @llvm.memcpy.p1i8.p0i8.i32(i8 addrspace(1)*, i8*, i32, i1)

;--- reject-size-mismatch.ll
define i8 addrspace(1)* @reject_size_mismatch(
    i8* %type.info, i8* %source, i32 %allocation.size,
    i32 %copy.length) gc "cangjie" {
entry:
  %object = call i8 addrspace(1)* @llvm.cj.alloca.generic(
      i8* %type.info, i32 %allocation.size)
  %object.fields = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.slot = getelementptr i8*, i8* addrspace(1)* %object.fields, i32 1
  %payload = bitcast i8* addrspace(1)* %payload.slot to i8 addrspace(1)*
  call void @llvm.memcpy.p1i8.p0i8.i32(i8 addrspace(1)* %payload,
                                       i8* %source, i32 %copy.length, i1 false)
  ret i8 addrspace(1)* %object
}

declare i8 addrspace(1)* @llvm.cj.alloca.generic(i8*, i32)
declare void @llvm.memcpy.p1i8.p0i8.i32(i8 addrspace(1)*, i8*, i32, i1)

;--- keep-non-as1.ll
define void @keep_non_as1_destination(
    i8* %type.info, i8* %source, i8* %destination,
    i32 %size) gc "cangjie" {
entry:
  %object = call i8 addrspace(1)* @llvm.cj.alloca.generic(i8* %type.info,
                                                          i32 %size)
  %object.fields = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.slot = getelementptr i8*, i8* addrspace(1)* %object.fields, i32 1
  %payload = bitcast i8* addrspace(1)* %payload.slot to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p0i8.i32(i8* %destination,
                                       i8* %source, i32 %size, i1 false)
  ret void
}

declare i8 addrspace(1)* @llvm.cj.alloca.generic(i8*, i32)
declare void @llvm.memcpy.p0i8.p0i8.i32(i8*, i8*, i32, i1)
