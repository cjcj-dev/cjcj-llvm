; RUN: opt -passes=cj-ir-verifier < %s -disable-output 2>&1 | FileCheck %s

%ObjLayout = type { i8 addrspace(1)*, i8 addrspace(1)* }

; CHECK: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]
; CHECK-NEXT: call void @llvm.memcpy.p1i8.p1i8.i64
; CHECK: in function as1_as1_objlayout_ref_copy
; CHECK-NOT: LLVM ERROR
define void @as1_as1_objlayout_ref_copy(i8 addrspace(1)* %dst,
                                        i8 addrspace(1)* %src) gc "cangjie" {
entry:
  %dst.typed = bitcast i8 addrspace(1)* %dst to %ObjLayout addrspace(1)*
  %src.typed = bitcast i8 addrspace(1)* %src to %ObjLayout addrspace(1)*
  call void @llvm.memcpy.p1i8.p1i8.i64(i8 addrspace(1)* %dst, i8 addrspace(1)* %src,
                                       i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p1i8.p1i8.i64(i8 addrspace(1)*, i8 addrspace(1)*, i64, i1)
