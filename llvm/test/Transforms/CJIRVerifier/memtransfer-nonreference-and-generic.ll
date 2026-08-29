; RUN: opt -passes=cj-ir-verifier < %s -disable-output

%plain = type { i64, i64 }
%mixed = type { i64, i8 addrspace(1)* }

; A known non-reference payload remains legal.
define void @allow_plain_memcpy() gc "cangjie" {
entry:
  %dst = alloca %plain, align 8
  %src = alloca %plain, align 8
  %dst.i8 = bitcast %plain* %dst to i8*
  %src.i8 = bitcast %plain* %src to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8,
                                       i64 16, i1 false)
  ret void
}

; A statically bounded span that ends before the reference field is not a
; reference payload and must not be over-captured by the aggregate type.
define void @allow_nonreference_prefix_of_mixed_payload() gc "cangjie" {
entry:
  %dst = alloca %mixed, align 8
  %src = alloca %mixed, align 8
  %dst.i8 = bitcast %mixed* %dst to i8*
  %src.i8 = bitcast %mixed* %src to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  call void @llvm.cj.memset(i8* %src.i8, i8 0, i64 16, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8,
                                       i64 8, i1 false)
  ret void
}

; Type-erased generic pointers have no statically recoverable payload type.
; This case remains explicitly unclassified until the frontend supplies a
; payload descriptor; it is not evidence that reference payload is safe.
define void @allow_unclassified_generic_memmove(i8* %dst, i8* %src,
                                                i64 %size) gc "cangjie" {
entry:
  call void @llvm.memmove.p0i8.p0i8.i64(i8* %dst, i8* %src,
                                        i64 %size, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
declare void @llvm.memmove.p0i8.p0i8.i64(i8*, i8*, i64, i1)
declare void @llvm.cj.memset(i8*, i8, i64, i1)
