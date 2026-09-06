; RUN: opt -passes=cj-ir-verifier < %s -disable-output 2>&1 | FileCheck %s --check-prefix=CHECK

%payload = type { i64, i8 addrspace(1)* }

; A dynamic copy size cannot prove that the known reference field is excluded,
; so the typed payload is rejected fail-closed.
; CHECK: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]
; CHECK-NEXT: call void @llvm.memcpy.p0i8.p0i8.i64
define void @reject_dynamic_bare_memcpy_ref_payload(i64 %size) gc "cangjie" {
entry:
  %dst = alloca %payload, align 8
  %src = alloca %payload, align 8
  %dst.i8 = bitcast %payload* %dst to i8*
  %src.i8 = bitcast %payload* %src to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  call void @llvm.cj.memset(i8* %src.i8, i8 0, i64 16, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8,
                                       i64 %size, i1 false)
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

