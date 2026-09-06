; RUN: not not opt -passes=cj-ir-verifier < %s -disable-output 2>&1 | FileCheck %s -check-prefixes=CHECK,ABORT

%ObjLayout = type { i8 addrspace(1)*, i8 addrspace(1)* }

; Same-SSA bitcast to a typed ObjLayout carrying AS1 fields; memcpy uses the
; erased AS1 carrier.  This is the heap-to-heap whole-object shape that the
; r3 Unknown report admitted.
; CHECK: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; CHECK-NEXT: call void @llvm.memcpy.p1i8.p1i8.i64
; CHECK: in function as1_as1_objlayout_ref_copy
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

; ABORT: LLVM ERROR: Broken function found, compilation aborted
; ABORT: error: Aborted
