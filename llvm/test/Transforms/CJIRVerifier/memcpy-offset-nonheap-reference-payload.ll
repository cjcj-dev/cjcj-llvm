; RUN: not not opt -passes=cj-ir-verifier < %s -disable-output 2>&1 | FileCheck %s -check-prefixes=CHECK,ABORT

%payload = type { i64, i8 addrspace(1)* }

; CHECK: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; CHECK-NEXT: call void @llvm.memcpy.p0i8.p0i8.i64
; CHECK: in function reject_offset_nonheap_memcpy_ref_payload
define void @reject_offset_nonheap_memcpy_ref_payload() gc "cangjie" {
entry:
  %dst = alloca %payload, align 8
  %src = alloca %payload, align 8
  %dst.ref = getelementptr inbounds %payload, %payload* %dst, i32 0, i32 1
  %src.ref = getelementptr inbounds %payload, %payload* %src, i32 0, i32 1
  %dst.i8 = bitcast i8 addrspace(1)** %dst.ref to i8*
  %src.i8 = bitcast i8 addrspace(1)** %src.ref to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8,
                                       i64 8, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)

; ABORT: LLVM ERROR: Broken function found, compilation aborted
; ABORT: error: Aborted
