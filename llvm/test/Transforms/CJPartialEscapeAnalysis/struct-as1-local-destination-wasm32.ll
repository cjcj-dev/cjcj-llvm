; RUN: opt -passes=cj-pea -S < %s | FileCheck %s
; REQUIRES: webassembly-registered-target
; On wasm32 a struct field of a stack object sits at +4 (payload) or +12 (array
; element) of an 8-byte aligned slot. The memcpy replacing the struct barrier
; may only promise the alignment of that offset, and nothing for an unknown
; source pointer.

target datalayout = "e-m:e-p:32:32-p10:8:8-p20:8:8-i64:64-n32:64-S128-ni:1:10:20"
target triple = "wasm32-unknown-wasi"

declare void @llvm.cj.gcwrite.struct.p0i8.i64(i8 addrspace(1)*, i8 addrspace(1)*, i8*, i64)

define void @local_destination_offsets(i8* %src) #0 gc "cangjie" {
; CHECK-LABEL: define void @local_destination_offsets(
; CHECK-NOT: call void @llvm.cj.gcwrite.struct
; CHECK: call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 4 %f4, i8* align 1 %src, i64 8, i1 false)
; CHECK: call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 4 %f12, i8* align 1 %src, i64 8, i1 false)
; CHECK: call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 8 %f16, i8* align 1 %src, i64 8, i1 false)
; CHECK-NOT: align 8 %f4
; CHECK-NOT: align 8 %f12
; CHECK: ret void
  %dst = alloca i8, i64 32, align 8
  %as1 = addrspacecast i8* %dst to i8 addrspace(1)*
  %f4 = getelementptr inbounds i8, i8 addrspace(1)* %as1, i32 4
  call void @llvm.cj.gcwrite.struct.p0i8.i64(i8 addrspace(1)* %as1, i8 addrspace(1)* %f4, i8* %src, i64 8)
  %f12 = getelementptr inbounds i8, i8 addrspace(1)* %as1, i32 12
  call void @llvm.cj.gcwrite.struct.p0i8.i64(i8 addrspace(1)* %as1, i8 addrspace(1)* %f12, i8* %src, i64 8)
  %f16 = getelementptr inbounds i8, i8 addrspace(1)* %as1, i32 16
  call void @llvm.cj.gcwrite.struct.p0i8.i64(i8 addrspace(1)* %as1, i8 addrspace(1)* %f16, i8* %src, i64 8)
  ret void
}
attributes #0 = { "hasMD" }
