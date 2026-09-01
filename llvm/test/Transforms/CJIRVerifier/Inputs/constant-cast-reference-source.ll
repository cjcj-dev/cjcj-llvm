%ref_payload = type { i8 addrspace(1)* }
@ref_source = internal global %ref_payload zeroinitializer

define void @constant_cast_reference_source_is_rejected() gc "cangjie" {
entry:
  %dst.array = alloca [8 x i8], align 8
  %dst = bitcast [8 x i8]* %dst.array to i8*
  call void @llvm.memmove.p0i8.p1i8.i64(i8* %dst,
      i8 addrspace(1)* addrspacecast (i8* bitcast (%ref_payload* @ref_source to i8*) to i8 addrspace(1)*), i64 8, i1 false)
  ret void
}

declare void @llvm.memmove.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
