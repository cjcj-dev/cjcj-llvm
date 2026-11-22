; RUN: opt -passes=cj-barrier-opt -S < %s | FileCheck %s
; RUN: opt -passes=cj-barrier-opt -S < %s | FileCheck %s --check-prefix=NOALIGN8
; wasm32: the object header is the 4-byte TypeInfo pointer, so in the 8-byte
; aligned stack object the array payload starts at +4 and element i at
; +12 + 24*i (4 mod 8). The raw copy that replaces a struct read/write barrier
; may only promise align 4 on that operand, on both the read and write side.
target datalayout = "e-m:e-p:32:32-p10:8:8-p20:8:8-i64:64-n32:64-S128-ni:1:10:20"
target triple = "wasm32-unknown-wasi"
; NOALIGN8-NOT: addrspace(1)* align 8

%TypeInfo = type { i8* }
%rec = type { i8 addrspace(1)*, i64, i64 }
%ArrayBase = type { i64 }
%ArrayLayout.rec = type { %ArrayBase, [0 x %rec] }


declare void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)*, i8 addrspace(1)*, i8*, i64)
declare void @llvm.cj.gcread.struct(i8*, i8 addrspace(1)*, i8 addrspace(1)*, i64)

; The production shape (o2live -O2): a stack array object whose elements are
; reached through the AS1 view of the payload with a variable index.
; CHECK-LABEL: define void @write_elem(
; CHECK-NOT: call void @llvm.cj.gcwrite.struct
; CHECK: call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 4 %dest, i8* align 8 %src.i8, i64 24, i1 false)
; CHECK: ret void
define void @write_elem(i32 %i) gc "cangjie" {
entry:
  %obj = alloca <{ %TypeInfo*, { %ArrayBase, [8 x %rec] }, [4 x i8] }>, align 8
  %src = alloca %rec, align 8
  %src.i8 = bitcast %rec* %src to i8*
  %obj.i8 = bitcast <{ %TypeInfo*, { %ArrayBase, [8 x %rec] }, [4 x i8] }>* %obj to i8*
  %obj.as1 = addrspacecast i8* %obj.i8 to i8 addrspace(1)*
  %obj.payload = getelementptr inbounds <{ %TypeInfo*, { %ArrayBase, [8 x %rec] }, [4 x i8] }>, <{ %TypeInfo*, { %ArrayBase, [8 x %rec] }, [4 x i8] }>* %obj, i32 0, i32 1
  %pl = bitcast { %ArrayBase, [8 x %rec] }* %obj.payload to %ArrayLayout.rec*
  %arr = addrspacecast %ArrayLayout.rec* %pl to %ArrayLayout.rec addrspace(1)*
  %idx = and i32 %i, 7
  %elem = getelementptr inbounds %ArrayLayout.rec, %ArrayLayout.rec addrspace(1)* %arr, i32 0, i32 1, i32 %idx
  %dest = bitcast %rec addrspace(1)* %elem to i8 addrspace(1)*
  call void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)* %obj.as1, i8 addrspace(1)* %dest, i8* %src.i8, i64 24)
  ret void
}

; CHECK-LABEL: define void @read_elem(
; CHECK-NOT: call void @llvm.cj.gcread.struct
; CHECK: call void @llvm.memcpy.p0i8.p1i8.i64(i8* align 8 %dst.i8, i8 addrspace(1)* align 4 %source, i64 24, i1 false)
; CHECK: ret void
define void @read_elem(i32 %i) gc "cangjie" {
entry:
  %obj = alloca <{ %TypeInfo*, { %ArrayBase, [8 x %rec] }, [4 x i8] }>, align 8
  %dst = alloca %rec, align 8
  %dst.i8 = bitcast %rec* %dst to i8*
  %obj.i8 = bitcast <{ %TypeInfo*, { %ArrayBase, [8 x %rec] }, [4 x i8] }>* %obj to i8*
  %obj.as1 = addrspacecast i8* %obj.i8 to i8 addrspace(1)*
  %obj.payload = getelementptr inbounds <{ %TypeInfo*, { %ArrayBase, [8 x %rec] }, [4 x i8] }>, <{ %TypeInfo*, { %ArrayBase, [8 x %rec] }, [4 x i8] }>* %obj, i32 0, i32 1
  %pl = bitcast { %ArrayBase, [8 x %rec] }* %obj.payload to %ArrayLayout.rec*
  %arr = addrspacecast %ArrayLayout.rec* %pl to %ArrayLayout.rec addrspace(1)*
  %idx = and i32 %i, 7
  %elem = getelementptr inbounds %ArrayLayout.rec, %ArrayLayout.rec addrspace(1)* %arr, i32 0, i32 1, i32 %idx
  %source = bitcast %rec addrspace(1)* %elem to i8 addrspace(1)*
  call void @llvm.cj.gcread.struct(i8* %dst.i8, i8 addrspace(1)* %obj.as1, i8 addrspace(1)* %source, i64 24)
  ret void
}
