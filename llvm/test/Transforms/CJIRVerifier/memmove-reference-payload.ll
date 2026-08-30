; RUN: not not opt -passes=cj-ir-verifier < %s -disable-output 2>&1 | FileCheck %s -check-prefixes=CHECK,ABORT

%payload = type { i64, i8 addrspace(1)* }

; CHECK: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; CHECK-NEXT: call void @llvm.memmove.p0i8.p1i8.i64
; CHECK: in function reject_as1_source_memmove_ref_payload
define void @reject_as1_source_memmove_ref_payload(
    %payload addrspace(1)* %src) gc "cangjie" {
entry:
  %dst = alloca %payload, align 8
  %dst.i8 = bitcast %payload* %dst to i8*
  %src.i8 = bitcast %payload addrspace(1)* %src to i8 addrspace(1)*
  call void @llvm.memmove.p0i8.p1i8.i64(i8* %dst.i8, i8 addrspace(1)* %src.i8,
                                        i64 16, i1 false)
  ret void
}

declare void @llvm.memmove.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)

; ABORT: LLVM ERROR: Broken function found, compilation aborted
; ABORT: error: Aborted
