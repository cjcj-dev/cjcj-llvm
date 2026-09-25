; RUN: opt -enable-new-pm=false -cj-barrier-split -S < %s | FileCheck %s
; RUN: opt -passes=cj-barrier-split -S < %s | FileCheck %s

%record = type { i8 addrspace(1)* }
%objlayout = type { i8*, %record }
%record1 = type { i64, i8 addrspace(1)* }
%objlayout1 = type { i8*, %record1 }
%record2 = type { i64, i8 addrspace(1)*, i64 }
%objlayout2 = type { i8*, %record2 }

declare void @llvm.cj.gcread.struct(i8*, i8 addrspace(1)*, i8 addrspace(1)*, i64)

; CHECK: entry1:
; CHECK-NEXT: %0 = bitcast i8 addrspace(1)* %this to %objlayout addrspace(1)*
; CHECK-NEXT: %1 = getelementptr inbounds %objlayout, %objlayout addrspace(1)* %0, i64 0, i32 1
; CHECK-NEXT: %2 = bitcast %record addrspace(1)* %1 to i8 addrspace(1)*
; CHECK-NEXT: %3 = bitcast %record* %value to i8*
; CHECK-NEXT: %4 = bitcast i8 addrspace(1)* %2 to i8 addrspace(1)* addrspace(1)*
; CHECK-NEXT: %5 = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %this, i8 addrspace(1)* addrspace(1)* %4)
; CHECK-NEXT: %6 = bitcast i8* %3 to i8 addrspace(1)**
; CHECK-NEXT: store i8 addrspace(1)* %5, i8 addrspace(1)** %6, align 8
; CHECK-NEXT: ret void


define void @foo(i8 addrspace(1)* %this, %record* %value) gc "cangjie" {
entry1:
  %0 = bitcast i8 addrspace(1)* %this to %objlayout addrspace(1)*
  %1 = getelementptr inbounds %objlayout, %objlayout addrspace(1)* %0, i64 0, i32 1
  %2 = bitcast %record addrspace(1)* %1 to i8 addrspace(1)*
  %3 = bitcast %record* %value to i8*
  call void @llvm.cj.gcread.struct(i8* %3, i8 addrspace(1)* %this, i8 addrspace(1)* %2, i64 8)
  ret void
}

; CHECK: entry2:
; CHECK-NEXT: %0 = bitcast i8 addrspace(1)* %this to %objlayout1 addrspace(1)*
; CHECK-NEXT: %1 = getelementptr inbounds %objlayout1, %objlayout1 addrspace(1)* %0, i64 0, i32 1
; CHECK-NEXT: %2 = bitcast %record1 addrspace(1)* %1 to i8 addrspace(1)*
; CHECK-NEXT: %3 = bitcast %record1* %value to i8*
; CHECK-NEXT: call void @llvm.memcpy.p0i8.p1i8.i64(i8* align 8 %3, i8 addrspace(1)* align 8 %2, i64 8, i1 false)
; CHECK-NEXT: %4 = getelementptr inbounds i8, i8* %3, i32 8
; CHECK-NEXT: %5 = getelementptr inbounds i8, i8 addrspace(1)* %2, i32 8
; CHECK-NEXT: %6 = bitcast i8 addrspace(1)* %5 to i8 addrspace(1)* addrspace(1)*
; CHECK-NEXT: %7 = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %this, i8 addrspace(1)* addrspace(1)* %6)
; CHECK-NEXT: %8 = bitcast i8* %4 to i8 addrspace(1)**
; CHECK-NEXT: store i8 addrspace(1)* %7, i8 addrspace(1)** %8, align 8
; CHECK-NEXT: ret void


define void @koo(i8 addrspace(1)* %this, %record1* %value) gc "cangjie" {
entry2:
  %0 = bitcast i8 addrspace(1)* %this to %objlayout1 addrspace(1)*
  %1 = getelementptr inbounds %objlayout1, %objlayout1 addrspace(1)* %0, i64 0, i32 1
  %2 = bitcast %record1 addrspace(1)* %1 to i8 addrspace(1)*
  %3 = bitcast %record1* %value to i8*
  call void @llvm.cj.gcread.struct(i8* %3, i8 addrspace(1)* %this, i8 addrspace(1)* %2, i64 16)
  ret void
}

; CHECK: entry3:
; CHECK-NEXT: %0 = bitcast i8 addrspace(1)* %this to %objlayout2 addrspace(1)*
; CHECK-NEXT: %1 = getelementptr inbounds %objlayout2, %objlayout2 addrspace(1)* %0, i64 0, i32 1
; CHECK-NEXT: %2 = bitcast %record2 addrspace(1)* %1 to i8 addrspace(1)*
; CHECK-NEXT: %3 = bitcast %record2* %value to i8*
; CHECK-NEXT: call void @llvm.memcpy.p0i8.p1i8.i64(i8* align 8 %3, i8 addrspace(1)* align 8 %2, i64 8, i1 false)
; CHECK-NEXT: %4 = getelementptr inbounds i8, i8* %3, i32 8
; CHECK-NEXT: %5 = getelementptr inbounds i8, i8 addrspace(1)* %2, i32 8
; CHECK-NEXT: %6 = bitcast i8 addrspace(1)* %5 to i8 addrspace(1)* addrspace(1)*
; CHECK-NEXT: %7 = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %this, i8 addrspace(1)* addrspace(1)* %6)
; CHECK-NEXT: %8 = bitcast i8* %4 to i8 addrspace(1)**
; CHECK-NEXT: store i8 addrspace(1)* %7, i8 addrspace(1)** %8, align 8
; CHECK-NEXT: %9 = getelementptr inbounds i8, i8* %3, i32 16
; CHECK-NEXT: %10 = getelementptr inbounds i8, i8 addrspace(1)* %2, i32 16
; CHECK-NEXT: call void @llvm.memcpy.p0i8.p1i8.i64(i8* align 8 %9, i8 addrspace(1)* align 8 %10, i64 8, i1 false)
; CHECK-NEXT: ret void


define void @hoo(i8 addrspace(1)* %this, %record2* %value) gc "cangjie" {
entry3:
  %0 = bitcast i8 addrspace(1)* %this to %objlayout2 addrspace(1)*
  %1 = getelementptr inbounds %objlayout2, %objlayout2 addrspace(1)* %0, i64 0, i32 1
  %2 = bitcast %record2 addrspace(1)* %1 to i8 addrspace(1)*
  %3 = bitcast %record2* %value to i8*
  call void @llvm.cj.gcread.struct(i8* %3, i8 addrspace(1)* %this, i8 addrspace(1)* %2, i64 24)
  ret void
}
