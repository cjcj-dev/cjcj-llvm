; RUN: opt -passes=cj-ir-verifier < %s -disable-output 2>&1 | FileCheck %s

; CHECK: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]
; CHECK-NEXT: call void @llvm.memcpy.p0i8.p0i8.i64
; CHECK-NOT: LLVM ERROR
define void @unknown_opaque_memcpy(i8* %dst, i8* %src) gc "cangjie" {
entry:
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst, i8* %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
