; RUN: opt -passes=cj-barrier-opt -S < %s | FileCheck %s
; RUN: opt -passes=cj-barrier-opt -S < %s | FileCheck %s --check-prefix=NOALIGN8
; wasm32: llvm.ptrmask clears low address bits, so offsets above the mask do
; not combine with offsets below it. In an 8-byte aligned stack object,
; +4 -> ptrmask(~7) -> +4 is 4 mod 8 (not the 8 that summing 4 + 4 gives):
; the raw copy that replaces the struct barrier may only promise align 4.
; With an unknown mask the result is only as aligned as the masked operand.
target datalayout = "e-m:e-p:32:32-p10:8:8-p20:8:8-i64:64-n32:64-S128-ni:1:10:20"
target triple = "wasm32-unknown-wasi"
; NOALIGN8-NOT: addrspace(1)* align 8

%TypeInfo = type { i8* }
%rec = type { i8 addrspace(1)*, i64, i64 }

declare void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)*, i8 addrspace(1)*, i8*, i64)
declare i8* @llvm.ptrmask.p0i8.i32(i8*, i32)

; CHECK-LABEL: define void @mask_then_offset(
; CHECK-NOT: call void @llvm.cj.gcwrite.struct
; CHECK: call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 4 %dest, i8* align 8 %src.i8, i64 24, i1 false)
; CHECK: ret void
define void @mask_then_offset() gc "cangjie" {
entry:
  %obj = alloca <{ %TypeInfo*, [36 x i8] }>, align 8
  %src = alloca %rec, align 8
  %src.i8 = bitcast %rec* %src to i8*
  %obj.i8 = bitcast <{ %TypeInfo*, [36 x i8] }>* %obj to i8*
  %obj.as1 = addrspacecast i8* %obj.i8 to i8 addrspace(1)*
  %up = getelementptr inbounds i8, i8* %obj.i8, i32 4
  %masked = call i8* @llvm.ptrmask.p0i8.i32(i8* %up, i32 -8)
  %down = getelementptr inbounds i8, i8* %masked, i32 4
  %dest = addrspacecast i8* %down to i8 addrspace(1)*
  call void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)* %obj.as1, i8 addrspace(1)* %dest, i8* %src.i8, i64 24)
  ret void
}

; CHECK-LABEL: define void @unknown_mask_then_offset(
; CHECK-NOT: call void @llvm.cj.gcwrite.struct
; CHECK: call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 4 %dest, i8* align 8 %src.i8, i64 24, i1 false)
; CHECK: ret void
define void @unknown_mask_then_offset(i32 %m) gc "cangjie" {
entry:
  %obj = alloca <{ %TypeInfo*, [36 x i8] }>, align 8
  %src = alloca %rec, align 8
  %src.i8 = bitcast %rec* %src to i8*
  %obj.i8 = bitcast <{ %TypeInfo*, [36 x i8] }>* %obj to i8*
  %obj.as1 = addrspacecast i8* %obj.i8 to i8 addrspace(1)*
  %up = getelementptr inbounds i8, i8* %obj.i8, i32 4
  %masked = call i8* @llvm.ptrmask.p0i8.i32(i8* %up, i32 %m)
  %down = getelementptr inbounds i8, i8* %masked, i32 4
  %dest = addrspacecast i8* %down to i8 addrspace(1)*
  call void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)* %obj.as1, i8 addrspace(1)* %dest, i8* %src.i8, i64 24)
  ret void
}
