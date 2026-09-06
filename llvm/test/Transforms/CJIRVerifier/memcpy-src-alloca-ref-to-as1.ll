; RUN: not not opt -passes=cj-ir-verifier < %s -disable-output 2>&1 | FileCheck %s -check-prefixes=CHECK,ABORT

%RefPayload = type { i8 addrspace(1)*, i64 }

; CHECK: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; CHECK-NEXT: call void @llvm.memcpy.p1i8.p0i8.i64
; CHECK: in function s1_src_alloca_ref_to_as1
define void @s1_src_alloca_ref_to_as1(i8 addrspace(1)* %dst) gc "cangjie" {
entry:
  %src.obj = alloca %RefPayload, align 8
  %src = bitcast %RefPayload* %src.obj to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)

; ABORT: LLVM ERROR: Broken function found, compilation aborted
; ABORT: error: Aborted
