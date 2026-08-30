; RUN: opt -passes=cj-ir-verifier < %s -disable-output

; A compile-time zero length moves no bytes, so opaque source and destination
; provenance cannot violate the typed GC barrier invariant.
define void @allow_zero_length_memcpy_with_unknown_provenance(
    i8 addrspace(1)* %dst, i8* %src) gc "cangjie" {
entry:
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %dst, i8* %src,
                                       i64 0, i1 false)
  ret void
}

declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)
