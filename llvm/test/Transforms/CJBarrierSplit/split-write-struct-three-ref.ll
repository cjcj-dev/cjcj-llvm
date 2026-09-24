; RUN: opt -cj-barrier-split -S < %s | FileCheck %s
; RUN: opt -passes=cj-barrier-split -S < %s | FileCheck %s

%record = type { i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)*, i64 }
%objlayout = type { i8*, %record }
%record1 = type { i8 addrspace(1)*, i64, i8 addrspace(1)*, i64, i8 addrspace(1)*, i64 }
%objlayout1 = type { i8*, %record1 }
%record2 = type { i64, i8 addrspace(1)*, i64, i8 addrspace(1)*, i64, i8 addrspace(1)* }
%objlayout2 = type { i8*, %record2 }

declare void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)*, i8 addrspace(1)*, i8*, i64)

; CHECK: entry1:
; CHECK-NEXT: %0 = bitcast i8 addrspace(1)* %this to %objlayout addrspace(1)*
; CHECK-NEXT: %1 = getelementptr inbounds %objlayout, %objlayout addrspace(1)* %0, i64 0, i32 1
; CHECK-NEXT: %2 = bitcast %record addrspace(1)* %1 to i8 addrspace(1)*
; CHECK-NEXT: %3 = bitcast %record* %value to i8*
; CHECK-NEXT: %4 = bitcast i8* %3 to i8 addrspace(1)**
; CHECK-NEXT: %5 = load i8 addrspace(1)*, i8 addrspace(1)** %4, align 8
; CHECK-NEXT: %6 = bitcast i8 addrspace(1)* %2 to i8 addrspace(1)* addrspace(1)*
; CHECK-NEXT: call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %5, i8 addrspace(1)* %this, i8 addrspace(1)* addrspace(1)* %6, i32 1)
; CHECK-NEXT: %7 = getelementptr inbounds i8, i8 addrspace(1)* %2, i32 8
; CHECK-NEXT: %8 = getelementptr inbounds i8, i8* %3, i32 8
; CHECK-NEXT: %9 = bitcast i8* %8 to i8 addrspace(1)**
; CHECK-NEXT: %10 = load i8 addrspace(1)*, i8 addrspace(1)** %9, align 8
; CHECK-NEXT: %11 = bitcast i8 addrspace(1)* %7 to i8 addrspace(1)* addrspace(1)*
; CHECK-NEXT: call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %10, i8 addrspace(1)* %this, i8 addrspace(1)* addrspace(1)* %11, i32 1)
; CHECK-NEXT: %12 = getelementptr inbounds i8, i8 addrspace(1)* %2, i32 16
; CHECK-NEXT: %13 = getelementptr inbounds i8, i8* %3, i32 16
; CHECK-NEXT: %14 = bitcast i8* %13 to i8 addrspace(1)**
; CHECK-NEXT: %15 = load i8 addrspace(1)*, i8 addrspace(1)** %14, align 8
; CHECK-NEXT: %16 = bitcast i8 addrspace(1)* %12 to i8 addrspace(1)* addrspace(1)*
; CHECK-NEXT: call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %15, i8 addrspace(1)* %this, i8 addrspace(1)* addrspace(1)* %16, i32 1)
; CHECK-NEXT: %17 = getelementptr inbounds i8, i8 addrspace(1)* %2, i32 24
; CHECK-NEXT: %18 = getelementptr inbounds i8, i8* %3, i32 24
; CHECK-NEXT: call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 8 %17, i8* align 8 %18, i64 8, i1 false)
; CHECK-NEXT: ret void


define void @foo(i8 addrspace(1)* %this, %record* %value) gc "cangjie" {
entry1:
  %0 = bitcast i8 addrspace(1)* %this to %objlayout addrspace(1)*
  %1 = getelementptr inbounds %objlayout, %objlayout addrspace(1)* %0, i64 0, i32 1
  %2 = bitcast %record addrspace(1)* %1 to i8 addrspace(1)*
  %3 = bitcast %record* %value to i8*
  call void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)* %this, i8 addrspace(1)* %2, i8* %3, i64 32)
  ret void
}

; CHECK: entry2:
; CHECK-NEXT: %0 = bitcast i8 addrspace(1)* %this to %objlayout1 addrspace(1)*
; CHECK-NEXT: %1 = getelementptr inbounds %objlayout1, %objlayout1 addrspace(1)* %0, i64 0, i32 1
; CHECK-NEXT: %2 = bitcast %record1 addrspace(1)* %1 to i8 addrspace(1)*
; CHECK-NEXT: %3 = bitcast %record1* %value to i8*
; CHECK-NEXT: %4 = bitcast i8* %3 to i8 addrspace(1)**
; CHECK-NEXT: %5 = load i8 addrspace(1)*, i8 addrspace(1)** %4, align 8
; CHECK-NEXT: %6 = bitcast i8 addrspace(1)* %2 to i8 addrspace(1)* addrspace(1)*
; CHECK-NEXT: call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %5, i8 addrspace(1)* %this, i8 addrspace(1)* addrspace(1)* %6, i32 1)
; CHECK-NEXT: %7 = getelementptr inbounds i8, i8 addrspace(1)* %2, i32 8
; CHECK-NEXT: %8 = getelementptr inbounds i8, i8* %3, i32 8
; CHECK-NEXT: call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 8 %7, i8* align 8 %8, i64 8, i1 false)
; CHECK-NEXT: %9 = getelementptr inbounds i8, i8 addrspace(1)* %2, i32 16
; CHECK-NEXT: %10 = getelementptr inbounds i8, i8* %3, i32 16
; CHECK-NEXT: %11 = bitcast i8* %10 to i8 addrspace(1)**
; CHECK-NEXT: %12 = load i8 addrspace(1)*, i8 addrspace(1)** %11, align 8
; CHECK-NEXT: %13 = bitcast i8 addrspace(1)* %9 to i8 addrspace(1)* addrspace(1)*
; CHECK-NEXT: call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %12, i8 addrspace(1)* %this, i8 addrspace(1)* addrspace(1)* %13, i32 1)
; CHECK-NEXT: %14 = getelementptr inbounds i8, i8 addrspace(1)* %2, i32 24
; CHECK-NEXT: %15 = getelementptr inbounds i8, i8* %3, i32 24
; CHECK-NEXT: call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 8 %14, i8* align 8 %15, i64 8, i1 false)
; CHECK-NEXT: %16 = getelementptr inbounds i8, i8 addrspace(1)* %2, i32 32
; CHECK-NEXT: %17 = getelementptr inbounds i8, i8* %3, i32 32
; CHECK-NEXT: %18 = bitcast i8* %17 to i8 addrspace(1)**
; CHECK-NEXT: %19 = load i8 addrspace(1)*, i8 addrspace(1)** %18, align 8
; CHECK-NEXT: %20 = bitcast i8 addrspace(1)* %16 to i8 addrspace(1)* addrspace(1)*
; CHECK-NEXT: call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %19, i8 addrspace(1)* %this, i8 addrspace(1)* addrspace(1)* %20, i32 1)
; CHECK-NEXT: %21 = getelementptr inbounds i8, i8 addrspace(1)* %2, i32 40
; CHECK-NEXT: %22 = getelementptr inbounds i8, i8* %3, i32 40
; CHECK-NEXT: call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 8 %21, i8* align 8 %22, i64 8, i1 false)
; CHECK-NEXT: ret void


define void @koo(i8 addrspace(1)* %this, %record1* %value) gc "cangjie" {
entry2:
  %0 = bitcast i8 addrspace(1)* %this to %objlayout1 addrspace(1)*
  %1 = getelementptr inbounds %objlayout1, %objlayout1 addrspace(1)* %0, i64 0, i32 1
  %2 = bitcast %record1 addrspace(1)* %1 to i8 addrspace(1)*
  %3 = bitcast %record1* %value to i8*
  call void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)* %this, i8 addrspace(1)* %2, i8* %3, i64 48)
  ret void
}

; CHECK: entry3:
; CHECK-NEXT: %0 = bitcast i8 addrspace(1)* %this to %objlayout2 addrspace(1)*
; CHECK-NEXT: %1 = getelementptr inbounds %objlayout2, %objlayout2 addrspace(1)* %0, i64 0, i32 1
; CHECK-NEXT: %2 = bitcast %record2 addrspace(1)* %1 to i8 addrspace(1)*
; CHECK-NEXT: %3 = bitcast %record2* %value to i8*
; CHECK-NEXT: call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 8 %2, i8* align 8 %3, i64 8, i1 false)
; CHECK-NEXT: %4 = getelementptr inbounds i8, i8 addrspace(1)* %2, i32 8
; CHECK-NEXT: %5 = getelementptr inbounds i8, i8* %3, i32 8
; CHECK-NEXT: %6 = bitcast i8* %5 to i8 addrspace(1)**
; CHECK-NEXT: %7 = load i8 addrspace(1)*, i8 addrspace(1)** %6, align 8
; CHECK-NEXT: %8 = bitcast i8 addrspace(1)* %4 to i8 addrspace(1)* addrspace(1)*
; CHECK-NEXT: call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %7, i8 addrspace(1)* %this, i8 addrspace(1)* addrspace(1)* %8, i32 1)
; CHECK-NEXT: %9 = getelementptr inbounds i8, i8 addrspace(1)* %2, i32 16
; CHECK-NEXT: %10 = getelementptr inbounds i8, i8* %3, i32 16
; CHECK-NEXT: call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 8 %9, i8* align 8 %10, i64 8, i1 false)
; CHECK-NEXT: %11 = getelementptr inbounds i8, i8 addrspace(1)* %2, i32 24
; CHECK-NEXT: %12 = getelementptr inbounds i8, i8* %3, i32 24
; CHECK-NEXT: %13 = bitcast i8* %12 to i8 addrspace(1)**
; CHECK-NEXT: %14 = load i8 addrspace(1)*, i8 addrspace(1)** %13, align 8
; CHECK-NEXT: %15 = bitcast i8 addrspace(1)* %11 to i8 addrspace(1)* addrspace(1)*
; CHECK-NEXT: call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %14, i8 addrspace(1)* %this, i8 addrspace(1)* addrspace(1)* %15, i32 1)
; CHECK-NEXT: %16 = getelementptr inbounds i8, i8 addrspace(1)* %2, i32 32
; CHECK-NEXT: %17 = getelementptr inbounds i8, i8* %3, i32 32
; CHECK-NEXT: call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 8 %16, i8* align 8 %17, i64 8, i1 false)
; CHECK-NEXT: %18 = getelementptr inbounds i8, i8 addrspace(1)* %2, i32 40
; CHECK-NEXT: %19 = getelementptr inbounds i8, i8* %3, i32 40
; CHECK-NEXT: %20 = bitcast i8* %19 to i8 addrspace(1)**
; CHECK-NEXT: %21 = load i8 addrspace(1)*, i8 addrspace(1)** %20, align 8
; CHECK-NEXT: %22 = bitcast i8 addrspace(1)* %18 to i8 addrspace(1)* addrspace(1)*
; CHECK-NEXT: call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %21, i8 addrspace(1)* %this, i8 addrspace(1)* addrspace(1)* %22, i32 1)
; CHECK-NEXT: ret void


define void @hoo(i8 addrspace(1)* %this, %record2* %value) gc "cangjie" {
entry3:
  %0 = bitcast i8 addrspace(1)* %this to %objlayout2 addrspace(1)*
  %1 = getelementptr inbounds %objlayout2, %objlayout2 addrspace(1)* %0, i64 0, i32 1
  %2 = bitcast %record2 addrspace(1)* %1 to i8 addrspace(1)*
  %3 = bitcast %record2* %value to i8*
  call void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)* %this, i8 addrspace(1)* %2, i8* %3, i64 48)
  ret void
}