; RUN: not not opt -passes=cj-ir-verifier < %s -disable-output 2>&1 | FileCheck %s -check-prefixes=CHECK,ABORT

%payload = type { i64, i8 addrspace(1)* }

; CHECK: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; CHECK-NEXT: call void @llvm.memmove.p0i8.p0i8.i64
; CHECK: in function reject_bare_memmove_ref_payload
define void @reject_bare_memmove_ref_payload() gc "cangjie" {
entry:
  %buf = alloca [2 x %payload], align 8
  %first = getelementptr inbounds [2 x %payload], [2 x %payload]* %buf, i64 0, i64 0
  %second = getelementptr inbounds [2 x %payload], [2 x %payload]* %buf, i64 0, i64 1
  %first.i8 = bitcast %payload* %first to i8*
  %second.i8 = bitcast %payload* %second to i8*
  call void @llvm.memmove.p0i8.p0i8.i64(i8* %second.i8, i8* %first.i8,
                                        i64 16, i1 false)
  ret void
}

declare void @llvm.memmove.p0i8.p0i8.i64(i8*, i8*, i64, i1)

; ABORT: LLVM ERROR: Broken function found, compilation aborted
; ABORT: error: Aborted
