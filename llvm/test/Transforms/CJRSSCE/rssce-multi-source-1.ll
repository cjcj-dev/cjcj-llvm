; RUN: opt -passes=cj-rssce -S < %s | FileCheck %s

%record.Q = type { i64, i64 }
%record.T = type { i64, %record.Q, i64, i64, %record.Q }
%record.P = type { i64, i64, %record.Q }

%ObjLayout.0 = type { i8* }
%ObjLayout.S = type { %ObjLayout.0, i64, i64, %record.Q }

; CHECK: 20:
; CHECK: call void @f2(i8* null, %record.T* %1)
define void @foo1(i8 addrspace(1)* nocapture readonly %s1, i8 addrspace(1)* nocapture readonly %s2) {
  %1 = alloca %record.T, align 8
  %2 = alloca %record.T, align 8
  %3 = bitcast i8 addrspace(1)* %s1 to %ObjLayout.S addrspace(1)*
  %4 = getelementptr inbounds %ObjLayout.S, %ObjLayout.S addrspace(1)* %3, i64 0, i32 1
  %5 = load i64, i64 addrspace(1)* %4, align 8
  %6 = getelementptr inbounds %record.T, %record.T* %1, i64 0, i32 0
  store i64 %5, i64* %6, align 8
  %7 = bitcast i8 addrspace(1)* %s2 to %ObjLayout.S addrspace(1)*
  %8 = getelementptr inbounds %ObjLayout.S, %ObjLayout.S addrspace(1)* %7, i64 0, i32 1
  %9 = bitcast i64 addrspace(1)* %8 to i8 addrspace(1)*
  %10 = getelementptr inbounds %record.T, %record.T* %1, i64 0, i32 2
  %11 = bitcast i64* %10 to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* noundef nonnull align 8 dereferenceable(16) %11, i8 addrspace(1)* noundef align 8 dereferenceable(16) %9, i64 16, i1 false)
  %12 = getelementptr inbounds %ObjLayout.S, %ObjLayout.S addrspace(1)* %3, i64 0, i32 3
  %13 = bitcast %record.Q addrspace(1)* %12 to i8 addrspace(1)*
  %14 = getelementptr inbounds %record.T, %record.T* %1, i64 0, i32 1
  %15 = bitcast %record.Q* %14 to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* noundef nonnull align 8 dereferenceable(16) %15, i8 addrspace(1)* noundef align 8 dereferenceable(16) %13, i64 16, i1 false)
  %16 = getelementptr inbounds %ObjLayout.S, %ObjLayout.S addrspace(1)* %7, i64 0, i32 3
  %17 = bitcast %record.Q addrspace(1)* %16 to i8 addrspace(1)*
  %18 = getelementptr inbounds %record.T, %record.T* %1, i64 0, i32 4
  %19 = bitcast %record.Q* %18 to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* noundef nonnull align 8 dereferenceable(16) %19, i8 addrspace(1)* noundef align 8 dereferenceable(16) %17, i64 16, i1 false)
  call void @f1(i8* null, %record.T* %1)
  br label %20

20:
  %21 = load i64, i64 addrspace(1)* %4, align 8
  %22 = getelementptr inbounds %record.T, %record.T* %2, i64 0, i32 0
  store i64 %21, i64* %22, align 8
  %23 = getelementptr inbounds %record.T, %record.T* %2, i64 0, i32 2
  %24 = bitcast i64* %23 to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* noundef nonnull align 8 dereferenceable(16) %24, i8 addrspace(1)* noundef align 8 dereferenceable(16) %9, i64 16, i1 false)
  %25 = getelementptr inbounds %record.T, %record.T* %2, i64 0, i32 1
  %26 = bitcast %record.Q* %25 to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* noundef nonnull align 8 dereferenceable(16) %26, i8 addrspace(1)* noundef align 8 dereferenceable(16) %13, i64 16, i1 false)
  %27 = getelementptr inbounds %record.T, %record.T* %2, i64 0, i32 4
  %28 = bitcast %record.Q* %27 to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* noundef nonnull align 8 dereferenceable(16) %28, i8 addrspace(1)* noundef align 8 dereferenceable(16) %17, i64 16, i1 false)
  call void @f2(i8* null, %record.T* %2)
  ret void
}

; CHECK: 20:
; CHECK: %24 = bitcast %record.T* %1 to i8*
; CHECK: %25 = getelementptr inbounds i8, i8* %24, i64 24
; CHECK: %26 = bitcast i8* %25 to %record.P*
; CHECK: call void @f3(i8* null, %record.P* %26)
define void @foo2(i8 addrspace(1)* nocapture readonly %s1, i8 addrspace(1)* nocapture readonly %s2) {
  %1 = alloca %record.T, align 8
  %2 = alloca %record.P, align 8
  %3 = bitcast i8 addrspace(1)* %s1 to %ObjLayout.S addrspace(1)*
  %4 = getelementptr inbounds %ObjLayout.S, %ObjLayout.S addrspace(1)* %3, i64 0, i32 1
  %5 = load i64, i64 addrspace(1)* %4, align 8
  %6 = getelementptr inbounds %record.T, %record.T* %1, i64 0, i32 0
  store i64 %5, i64* %6, align 8
  %7 = bitcast i8 addrspace(1)* %s2 to %ObjLayout.S addrspace(1)*
  %8 = getelementptr inbounds %ObjLayout.S, %ObjLayout.S addrspace(1)* %7, i64 0, i32 1
  %9 = bitcast i64 addrspace(1)* %8 to i8 addrspace(1)*
  %10 = getelementptr inbounds %record.T, %record.T* %1, i64 0, i32 2
  %11 = bitcast i64* %10 to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* noundef nonnull align 8 dereferenceable(16) %11, i8 addrspace(1)* noundef align 8 dereferenceable(16) %9, i64 16, i1 false)
  %12 = getelementptr inbounds %ObjLayout.S, %ObjLayout.S addrspace(1)* %3, i64 0, i32 3
  %13 = bitcast %record.Q addrspace(1)* %12 to i8 addrspace(1)*
  %14 = getelementptr inbounds %record.T, %record.T* %1, i64 0, i32 1
  %15 = bitcast %record.Q* %14 to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* noundef nonnull align 8 dereferenceable(16) %15, i8 addrspace(1)* noundef align 8 dereferenceable(16) %13, i64 16, i1 false)
  %16 = getelementptr inbounds %ObjLayout.S, %ObjLayout.S addrspace(1)* %7, i64 0, i32 3
  %17 = bitcast %record.Q addrspace(1)* %16 to i8 addrspace(1)*
  %18 = getelementptr inbounds %record.T, %record.T* %1, i64 0, i32 4
  %19 = bitcast %record.Q* %18 to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* noundef nonnull align 8 dereferenceable(16) %19, i8 addrspace(1)* noundef align 8 dereferenceable(16) %17, i64 16, i1 false)
  call void @f1(i8* null, %record.T* %1)
  br label %20

20:
  %21 = bitcast %record.P* %2 to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* noundef nonnull align 8 dereferenceable(16) %21, i8 addrspace(1)* noundef align 8 dereferenceable(16) %9, i64 16, i1 false)
  %22 = getelementptr inbounds %record.P, %record.P* %2, i64 0, i32 2
  %23 = bitcast %record.Q* %22 to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* noundef nonnull align 8 dereferenceable(16) %23, i8 addrspace(1)* noundef align 8 dereferenceable(16) %17, i64 16, i1 false)
  call void @f3(i8* null, %record.P* %2)
  ret void
}

declare void @f1(i8* %"$BP", %record.T* noalias nocapture readonly %t) #1
declare void @f2(i8* %"$BP", %record.T* noalias nocapture readonly %t) #1
declare void @f3(i8* %"$BP", %record.P* noalias nocapture readonly %p) #1

declare void @llvm.memcpy.p0i8.p1i8.i64(i8* noalias nocapture writeonly, i8 addrspace(1)* noalias nocapture readonly, i64, i1 immarg) #0

attributes #0 = { argmemonly nocallback nofree nounwind willreturn }
attributes #1 = { argmemonly }
