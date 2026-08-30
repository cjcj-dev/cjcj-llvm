; RUN: not not opt -passes=cj-ir-verifier < %s -disable-output 2>&1 | FileCheck %s -check-prefixes=CHECK,ABORT

%payload = type { i8 addrspace(1)* }

; CHECK: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; CHECK-NEXT: call void @llvm.memcpy.p0i8.p0i8.i64
; CHECK: in function reject_nonzero_memcpy_with_reference_payload
define void @reject_nonzero_memcpy_with_reference_payload() gc "cangjie" {
entry:
  %dst = alloca %payload, align 8
  %src = alloca %payload, align 8
  %dst.i8 = bitcast %payload* %dst to i8*
  %src.i8 = bitcast %payload* %src to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 8, i1 false)
  call void @llvm.cj.memset(i8* %src.i8, i8 0, i64 8, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8,
                                       i64 8, i1 false)
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

; ABORT: LLVM ERROR: Broken function found, compilation aborted
; ABORT: error: Aborted
