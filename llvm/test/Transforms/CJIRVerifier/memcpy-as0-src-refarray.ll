; RUN: opt -passes=cj-ir-verifier < %s -disable-output 2>&1 | FileCheck %s

%ArrayBase = type { i64 }
%RefElement = type { i8 addrspace(1)* }
%ArrayLayout.Ref = type { %ArrayBase, [0 x %RefElement] }

; CHECK: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]
; CHECK-NEXT: call void @llvm.memcpy.p1i8.p0i8.i64
; CHECK: in function n4_refarray_dst_as0_src
; CHECK-NOT: LLVM ERROR
define void @n4_refarray_dst_as0_src(i8 addrspace(1)* %dst.base, i8* %src, i64 %size) gc "cangjie" {
entry:
  %dst.layout = bitcast i8 addrspace(1)* %dst.base to %ArrayLayout.Ref addrspace(1)*
  %dst.payload = getelementptr inbounds %ArrayLayout.Ref, %ArrayLayout.Ref addrspace(1)* %dst.layout, i32 0, i32 1
  %dst = bitcast [0 x %RefElement] addrspace(1)* %dst.payload to i8 addrspace(1)*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %dst, i8* %src, i64 %size, i1 false)
  ret void
}

declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)
