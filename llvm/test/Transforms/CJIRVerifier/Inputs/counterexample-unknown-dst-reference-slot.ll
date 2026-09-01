; The destination carrier is erased at the memmove, but the preceding typed
; access proves that byte 0 is a managed-reference slot and stores %live there.
; Copying eight zero bytes then overwrites that reference through bare memmove.
%ref_payload = type { i8 addrspace(1)* }
@zeros = internal constant [8 x i8] zeroinitializer

define void @unknown_dst_actually_contains_reference(i8 addrspace(1)* %obj,
                                                     i8 addrspace(1)* %live) gc "cangjie" {
entry:
  %typed = bitcast i8 addrspace(1)* %obj to %ref_payload addrspace(1)*
  %slot = getelementptr inbounds %ref_payload, %ref_payload addrspace(1)* %typed, i32 0, i32 0
  store i8 addrspace(1)* %live, i8 addrspace(1)* addrspace(1)* %slot
  call void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)* %obj,
      i8 addrspace(1)* addrspacecast (i8* getelementptr inbounds ([8 x i8], [8 x i8]* @zeros, i32 0, i32 0) to i8 addrspace(1)*), i64 8, i1 false)
  ret void
}

declare void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)*, i8 addrspace(1)*, i64, i1)
