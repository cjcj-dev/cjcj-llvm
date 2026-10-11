; RUN: opt -passes=cj-rssce -S < %s | FileCheck %s

%record.Q = type { i64, i64 }
%record.T = type { i64, i64, %record.Q }

%ObjLayout.0 = type { i8* }
%ObjLayout.S = type { %ObjLayout.0, i64, i64, %record.T }

; CHECK: %10 = bitcast %record.T* %2 to i8*
; CHECK: %11 = getelementptr inbounds i8, i8* %10, i64 16
; CHECK: %12 = bitcast i8* %11 to %record.Q*
; CHECK: call void @f2(i8* null, %record.Q* nonnull %12)
define void @foo(i8 addrspace(1)* nocapture readonly %s) {
  %1 = alloca %record.Q, align 8
  %2 = alloca %record.T, align 8
  %3 = bitcast i8 addrspace(1)* %s to %ObjLayout.S addrspace(1)*
  %4 = getelementptr inbounds %ObjLayout.S, %ObjLayout.S addrspace(1)* %3, i64 0, i32 3
  %5 = bitcast %record.T* %2 to i8*
  %6 = bitcast %record.T addrspace(1)* %4 to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* noundef nonnull align 8 dereferenceable(32) %5, i8 addrspace(1)* noundef align 8 dereferenceable(32) %6, i64 32, i1 false)
  call void @f1(i8* null, %record.T* nonnull %2)
  %7 = getelementptr inbounds %ObjLayout.S, %ObjLayout.S addrspace(1)* %3, i64 0, i32 3, i32 2
  %8 = bitcast %record.Q* %1 to i8*
  %9 = bitcast %record.Q addrspace(1)* %7 to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* noundef nonnull align 8 dereferenceable(16) %8, i8 addrspace(1)* noundef align 8 dereferenceable(16) %9, i64 16, i1 false)
  call void @f2(i8* null, %record.Q* nonnull %1)
  ret void
}

declare void @f1(i8* %"$BP", %record.T* noalias nocapture readonly %t) #1
declare void @f2(i8* %"$BP", %record.Q* noalias nocapture readonly %q) #1

declare void @llvm.memcpy.p0i8.p1i8.i64(i8* noalias nocapture writeonly, i8 addrspace(1)* noalias nocapture readonly, i64, i1 immarg) #0

attributes #0 = { argmemonly nocallback nofree nounwind willreturn }
attributes #1 = { argmemonly }
