; RUN: opt -passes=cj-ir-verifier < %s -disable-output 2>&1 | FileCheck %s

; String literal materialization copies packed constant bytes into a fresh
; UInt8 RawArray payload; no managed references exist on either side.
; CHECK-NOT: in function constant_bytes_to_u8_array
; CHECK-NOT: in function constant_bytes_offset_to_u8_array
; CHECK: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]
; CHECK-NEXT: call void @llvm.memcpy.p1i8.p0i8.i64
; CHECK-NEXT: in function mutable_bytes_to_u8_array
; CHECK: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]
; CHECK-NEXT: call void @llvm.memcpy.p1i8.p0i8.i64
; CHECK-NEXT: in function constant_bytes_overrun_u8_array
; CHECK-NOT: in function constant_bytes_to_u8_array
; CHECK-NOT: LLVM ERROR

%ArrayBase = type { i64 }
%ArrayLayout.UInt8 = type { %ArrayBase, [0 x i8] }

@bytes = private unnamed_addr constant [8 x i8] c"abcdefgh"
@mutable = private global [8 x i8] c"abcdefgh"

define void @constant_bytes_to_u8_array(i8 addrspace(1)* %base) gc "cangjie" {
entry:
  %layout = bitcast i8 addrspace(1)* %base to %ArrayLayout.UInt8 addrspace(1)*
  %dst = getelementptr inbounds %ArrayLayout.UInt8, %ArrayLayout.UInt8 addrspace(1)* %layout, i32 0, i32 1, i64 0
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 1 %dst, i8* align 1 getelementptr inbounds ([8 x i8], [8 x i8]* @bytes, i32 0, i32 0), i64 8, i1 false)
  ret void
}

define void @constant_bytes_offset_to_u8_array(i8 addrspace(1)* %base) gc "cangjie" {
entry:
  %layout = bitcast i8 addrspace(1)* %base to %ArrayLayout.UInt8 addrspace(1)*
  %dst = getelementptr inbounds %ArrayLayout.UInt8, %ArrayLayout.UInt8 addrspace(1)* %layout, i32 0, i32 1, i64 0
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 1 %dst, i8* align 1 getelementptr inbounds ([8 x i8], [8 x i8]* @bytes, i32 0, i32 3), i64 5, i1 false)
  ret void
}

define void @mutable_bytes_to_u8_array(i8 addrspace(1)* %base) gc "cangjie" {
entry:
  %layout = bitcast i8 addrspace(1)* %base to %ArrayLayout.UInt8 addrspace(1)*
  %dst = getelementptr inbounds %ArrayLayout.UInt8, %ArrayLayout.UInt8 addrspace(1)* %layout, i32 0, i32 1, i64 0
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 1 %dst, i8* align 1 getelementptr inbounds ([8 x i8], [8 x i8]* @mutable, i32 0, i32 0), i64 8, i1 false)
  ret void
}

define void @constant_bytes_overrun_u8_array(i8 addrspace(1)* %base) gc "cangjie" {
entry:
  %layout = bitcast i8 addrspace(1)* %base to %ArrayLayout.UInt8 addrspace(1)*
  %dst = getelementptr inbounds %ArrayLayout.UInt8, %ArrayLayout.UInt8 addrspace(1)* %layout, i32 0, i32 1, i64 0
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 1 %dst, i8* align 1 getelementptr inbounds ([8 x i8], [8 x i8]* @bytes, i32 0, i32 4), i64 8, i1 false)
  ret void
}

declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)
