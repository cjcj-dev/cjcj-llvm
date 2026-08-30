; RUN: opt -passes=cj-ir-verifier < %s -disable-output

%payload = type { i8 addrspace(1)* }

; Stack/runtime roots stay plain. This is the IR analogue of
; Barrier.cpp::CopyStructPlainToNonHeap's non-heap memmove path.
define void @allow_complete_nonheap_memcpy_with_reference_payload() gc "cangjie" {
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
