@bytes9 = internal constant [9 x i8] zeroinitializer

define void @constant_cast_nonzero_offset_stays_unknown() gc "cangjie" {
entry:
  %dst.array = alloca [8 x i8], align 8
  %dst = bitcast [8 x i8]* %dst.array to i8*
  call void @llvm.memmove.p0i8.p1i8.i64(i8* %dst,
      i8 addrspace(1)* addrspacecast (i8* getelementptr inbounds ([9 x i8], [9 x i8]* @bytes9, i32 0, i32 1) to i8 addrspace(1)*), i64 8, i1 false)
  ret void
}

declare void @llvm.memmove.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
