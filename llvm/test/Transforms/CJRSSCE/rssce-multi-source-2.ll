; RUN: opt -passes=cj-rssce -S < %s | FileCheck %s

%record.Q = type { i64, i64 }
%record.T = type { i64, %record.Q, i64, i64, %record.Q }
%record.P = type { %record.Q, i64, i64 }
%record.R = type { i64, i64, %record.Q }

%ObjLayout.0 = type { i8* }
%ObjLayout.S = type { %ObjLayout.0, i64, i64, %record.Q }

; CHECK: use1:
; CHECK: %20 = bitcast %record.T* %1 to i8*
; CHECK: %21 = getelementptr inbounds i8, i8* %20, i64 40
; CHECK: %22 = bitcast i8* %21 to %record.Q*
; CHECK: call void @f1(i8* null, %record.Q* %22)
; CHECK: redefineQ1:
; CHECK: call void @f1(i8* null, %record.Q* %2)
; CHECK: invalidT:
; CHECK-NEXT: call void @invalid_t(%record.T* %1)
; CHECK-NEXT: call void @f1(i8* null, %record.Q* %2)
define void @foo1(i8 addrspace(1)* %s, %record.P* nocapture readonly %p, i64 %tag) {
  %1 = alloca %record.T
  %2 = alloca %record.Q
  %3 = bitcast i8 addrspace(1)* %s to %ObjLayout.S addrspace(1)*
  ; %s[16, 40] -> %1[0, 24]
  %4 = bitcast %record.T* %1 to i8*
  %5 = getelementptr inbounds %ObjLayout.S, %ObjLayout.S addrspace(1)* %3, i64 0, i32 2
  %6 = bitcast i64 addrspace(1)* %5 to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* noundef nonnull align 8 dereferenceable(16) %4, i8 addrspace(1)* noundef align 8 dereferenceable(16) %6, i64 24, i1 false)
  ; %s[8, 40] -> %1[24, 56]
  %7 = getelementptr inbounds %record.T, %record.T* %1, i64 0, i32 2
  %8 = bitcast i64* %7 to i8*
  %9 = getelementptr inbounds %ObjLayout.S, %ObjLayout.S addrspace(1)* %3, i64 0, i32 1
  %10 = bitcast i64 addrspace(1)* %9 to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* noundef nonnull align 8 dereferenceable(16) %8, i8 addrspace(1)* noundef align 8 dereferenceable(16) %10, i64 32, i1 false)
  ; %p[0, 32] -> %1[8, 40]
  %11 = bitcast %record.P* %p to i8*
  %12 = getelementptr inbounds %record.T, %record.T* %1, i64 0, i32 1
  %13 = bitcast %record.Q* %12 to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* noundef nonnull align 8 dereferenceable(16) %13, i8* noundef align 8 dereferenceable(16) %11, i64 32, i1 false)
  br label %use1

use1:
  %14 = getelementptr inbounds %record.Q, %record.Q* %2, i64 0, i32 0
  %15 = getelementptr inbounds %ObjLayout.S, %ObjLayout.S addrspace(1)* %3, i64 0, i32 3, i32 0
  %16 = load i64, i64 addrspace(1)* %15, align 8
  store i64 %16, i64* %14, align 8
  %17 = getelementptr inbounds %record.Q, %record.Q* %2, i64 0, i32 1
  %18 = getelementptr inbounds %ObjLayout.S, %ObjLayout.S addrspace(1)* %3, i64 0, i32 3, i32 1
  %19 = load i64, i64 addrspace(1)* %18, align 8
  store i64 %19, i64* %17, align 8
  call void @f1(i8* null, %record.Q* %2)
  %icmp = icmp eq i64 %tag, 0
  br i1 %icmp, label %invalidS, label %invalidT

invalidS:
  call void @invalid_s(i8 addrspace(1)* %s)
  br label %redefineQ1

redefineQ1:
  %20 = bitcast %record.Q* %2 to i8*
  %21 = getelementptr inbounds %ObjLayout.S, %ObjLayout.S addrspace(1)* %3, i64 0, i32 3
  %22 = bitcast %record.Q addrspace(1)* %21 to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* noundef nonnull align 8 dereferenceable(16) %20, i8 addrspace(1)* noundef align 8 dereferenceable(16) %22, i64 16, i1 false)
  call void @f1(i8* null, %record.Q* %2)
  br label %ret

invalidT:
  call void @invalid_t(%record.T* %1)
  call void @f1(i8* null, %record.Q* %2)
  br label %ret

ret:
  ret void
}

; CHECK: use:
; CHECK-NEXT: %14 = bitcast %record.R* %2 to i8*
; CHECK-NEXT: call void @llvm.memcpy.p0i8.p1i8.i64(i8* noundef nonnull align 8 dereferenceable(16) %14, i8 addrspace(1)* noundef align 8 dereferenceable(16) %10, i64 32, i1 false)
; CHECK-NEXT: %15 = bitcast %record.T* %1 to i8*
; CHECK-NEXT: %16 = getelementptr inbounds i8, i8* %15, i64 24
; CHECK-NEXT: %17 = bitcast i8* %16 to %record.R*
; CHECK-NEXT: call void @f2(%record.R* %17)
define void @foo2(i8 addrspace(1)* %s, %record.P* nocapture readonly %p, i64 %tag) {
  %1 = alloca %record.T
  %2 = alloca %record.R
  %3 = bitcast i8 addrspace(1)* %s to %ObjLayout.S addrspace(1)*
  ; %s[16, 40] -> %1[0, 24]
  %4 = bitcast %record.T* %1 to i8*
  %5 = getelementptr inbounds %ObjLayout.S, %ObjLayout.S addrspace(1)* %3, i64 0, i32 2
  %6 = bitcast i64 addrspace(1)* %5 to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* noundef nonnull align 8 dereferenceable(16) %4, i8 addrspace(1)* noundef align 8 dereferenceable(16) %6, i64 24, i1 false)
  ; %s[8, 40] -> %1[24, 56]
  %7 = getelementptr inbounds %record.T, %record.T* %1, i64 0, i32 2
  %8 = bitcast i64* %7 to i8*
  %9 = getelementptr inbounds %ObjLayout.S, %ObjLayout.S addrspace(1)* %3, i64 0, i32 1
  %10 = bitcast i64 addrspace(1)* %9 to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* noundef nonnull align 8 dereferenceable(16) %8, i8 addrspace(1)* noundef align 8 dereferenceable(16) %10, i64 32, i1 false)
  ; %p[0, 32] -> %1[8, 40]
  %11 = bitcast %record.P* %p to i8*
  %12 = getelementptr inbounds %record.T, %record.T* %1, i64 0, i32 1
  %13 = bitcast %record.Q* %12 to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* noundef nonnull align 8 dereferenceable(16) %13, i8* noundef align 8 dereferenceable(16) %11, i64 32, i1 false)
  ; %s[8, 24] -> %1[24, 40]
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* noundef nonnull align 8 dereferenceable(16) %8, i8 addrspace(1)* noundef align 8 dereferenceable(16) %10, i64 16, i1 false)
  br label %use

use:
  %14 = bitcast %record.R* %2 to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* noundef nonnull align 8 dereferenceable(16) %14, i8 addrspace(1)* noundef align 8 dereferenceable(16) %10, i64 32, i1 false)
  call void @f2(%record.R* %2)
  ret void
}

declare void @llvm.memcpy.p0i8.p1i8.i64(i8* noalias nocapture writeonly, i8 addrspace(1)* noalias nocapture readonly, i64, i1 immarg) #0
declare void @llvm.memcpy.p0i8.p0i8.i64(i8* noalias nocapture writeonly, i8* noalias nocapture readonly, i64, i1 immarg) #0

declare void @f1(i8* %"$BP", %record.Q* noalias nocapture readonly %q) #1
declare void @invalid_s(i8 addrspace(1)* %s)
declare void @invalid_t(%record.T* %t)
declare void @f2(%record.R* noalias nocapture readonly %r) #1

attributes #0 = { argmemonly nocallback nofree nounwind willreturn }
attributes #1 = { argmemonly }
