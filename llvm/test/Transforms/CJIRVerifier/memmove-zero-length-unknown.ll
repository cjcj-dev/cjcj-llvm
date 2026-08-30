; RUN: opt -passes=cj-ir-verifier < %s -disable-output

; Use the aggregate-zero spelling to ensure the verifier checks ConstantInt
; value semantics rather than the textual spelling of zero.
define void @allow_zero_length_memmove_with_unknown_provenance(
    i8* %dst, i8* %src) gc "cangjie" {
entry:
  call void @llvm.memmove.p0i8.p0i8.i64(i8* %dst, i8* %src,
                                        i64 zeroinitializer, i1 false)
  ret void
}

declare void @llvm.memmove.p0i8.p0i8.i64(i8*, i8*, i64, i1)
