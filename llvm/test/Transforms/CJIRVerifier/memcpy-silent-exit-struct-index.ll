; RUN: split-file %s %t
; RUN: opt -passes=cj-ir-verifier < %t/m2-struct-preceding-index.ll -disable-output 2>&1 | FileCheck %s -check-prefix=M2
; RUN: opt -passes=cj-ir-verifier < %t/m3-array-of-struct-index.ll -disable-output 2>&1 | FileCheck %s -check-prefix=M3

; M2: [silent-exit:multi-index] [unknown-payload:report]
; M2: in function m2_struct_preceding_index
; M2-NOT: LLVM ERROR
; M3: [silent-exit:multi-index] [unknown-payload:report]
; M3: in function m3_array_of_struct_index
; M3-NOT: LLVM ERROR

;--- m2-struct-preceding-index.ll
%Plain8 = type { i64 }
%Container = type { i8*, i8* }

define void @m2_struct_preceding_index(i8 addrspace(1)* %object) gc "cangjie" {
entry:
  %container = bitcast i8 addrspace(1)* %object to %Container addrspace(1)*
  %payload.raw = getelementptr inbounds %Container, %Container addrspace(1)* %container, i32 0, i32 1
  %payload.typed = bitcast i8* addrspace(1)* %payload.raw to %Plain8 addrspace(1)*
  %src = bitcast %Plain8 addrspace(1)* %payload.typed to i8 addrspace(1)*
  %dst.object = alloca %Plain8, align 8
  %dst = bitcast %Plain8* %dst.object to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst, i8 addrspace(1)* %src, i64 8, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)

;--- m3-array-of-struct-index.ll
%Plain8 = type { i64 }
%Slot = type { i8* }

define void @m3_array_of_struct_index(i8 addrspace(1)* %object) gc "cangjie" {
entry:
  %container = bitcast i8 addrspace(1)* %object to [2 x %Slot] addrspace(1)*
  %payload.raw = getelementptr [2 x %Slot], [2 x %Slot] addrspace(1)* %container, i32 0, i32 1
  %payload.typed = bitcast %Slot addrspace(1)* %payload.raw to %Plain8 addrspace(1)*
  %src = bitcast %Plain8 addrspace(1)* %payload.typed to i8 addrspace(1)*
  %dst.object = alloca %Plain8, align 8
  %dst = bitcast %Plain8* %dst.object to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst, i8 addrspace(1)* %src, i64 8, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
