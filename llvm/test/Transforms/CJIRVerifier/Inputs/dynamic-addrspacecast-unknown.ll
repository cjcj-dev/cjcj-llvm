define void @dynamic_addrspacecast_stays_unknown(i8* %raw) gc "cangjie" {
entry:
  %dst.array = alloca [8 x i8], align 8
  %dst = bitcast [8 x i8]* %dst.array to i8*
  %src = addrspacecast i8* %raw to i8 addrspace(1)*
  call void @llvm.memmove.p0i8.p1i8.i64(i8* %dst, i8 addrspace(1)* %src, i64 8, i1 false)
  ret void
}

declare void @llvm.memmove.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
