; RUN: not not opt -passes=cj-ir-verifier < %s -disable-output 2>&1 | FileCheck %s -check-prefixes=CHECK,ABORT

%ObjLayout.R = type { i8 addrspace(1)*, i64 }

; CHECK: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; CHECK-NEXT: call void @llvm.memcpy.p1i8.p0i8.i64
; CHECK: in function s2b_typed_objlayout_dst_nostore
define void @s2b_typed_objlayout_dst_nostore(i8 addrspace(1)* %obj, i8* %src) gc "cangjie" {
entry:
  %layout = bitcast i8 addrspace(1)* %obj to %ObjLayout.R addrspace(1)*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %obj, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)

; ABORT: LLVM ERROR: Broken function found, compilation aborted
; ABORT: error: Aborted
