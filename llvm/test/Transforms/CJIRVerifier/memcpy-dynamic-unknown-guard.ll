; RUN: opt -passes=cj-ir-verifier < %s -disable-output 2>&1 | FileCheck %s --check-prefix=CHECK

; CHECK: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]
; CHECK-NEXT: call void @llvm.memcpy.p1i8.p0i8.i64
define void @reject_dynamic_memcpy_with_unknown_provenance(
    i8 addrspace(1)* %dst, i8* %src, i64 %size) gc "cangjie" {
entry:
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %dst, i8* %src,
                                       i64 %size, i1 false)
  ret void
}

declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)

