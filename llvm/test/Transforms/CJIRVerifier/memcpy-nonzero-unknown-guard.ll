; RUN: not not opt -passes=cj-ir-verifier < %s -disable-output 2>&1 | FileCheck %s -check-prefixes=CHECK,ABORT

; CHECK: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance.
; CHECK-NEXT: call void @llvm.memcpy.p1i8.p0i8.i64
; CHECK: in function reject_nonzero_memcpy_with_unknown_provenance
define void @reject_nonzero_memcpy_with_unknown_provenance(
    i8 addrspace(1)* %dst, i8* %src) gc "cangjie" {
entry:
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %dst, i8* %src,
                                       i64 1, i1 false)
  ret void
}

declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)

; ABORT: LLVM ERROR: Broken function found, compilation aborted
; ABORT: error: Aborted
