; RUN: opt -passes=cj-annotation-outline -verify-each -S %s | FileCheck %s
;
; A musttail callee has the original factory prototype. Appending static-slot
; parameters to the enclosing helper invalidates that relationship. Keep both
; musttail bodies intact; ordinary calls with the same body remain outlineable.

%Arr = type { [32 x i8] }
declare i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** nocapture)
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
@_CAO7default3fooE = internal global i8 addrspace(1)* null
@_CAO7default3barE = internal global i8 addrspace(1)* null
@_CAO7default3bazE = internal global i8 addrspace(1)* null
@_CAO7default3quxE = internal global i8 addrspace(1)* null

declare void @finish(%Arr*)

; CHECK-LABEL: define void @_CAFmusttailA(%Arr* %0)
; CHECK-NOT: _imp(
; CHECK: %1 = addrspacecast %Arr* %0 to %Arr addrspace(1)*
; CHECK: call i8 addrspace(1)* @llvm.cj.gcread.static.ref
; CHECK: musttail call void @finish(%Arr* %0)
; CHECK-NEXT: ret void
define void @_CAFmusttailA(%Arr* %0) gc "cangjie" {
bb0:
  %1 = addrspacecast %Arr* %0 to %Arr addrspace(1)*
  %2 = bitcast %Arr addrspace(1)* %1 to i8 addrspace(1)*
  %3 = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @_CAO7default3fooE)
  %4 = getelementptr i8, i8 addrspace(1)* %2, i64 16
  %5 = bitcast i8 addrspace(1)* %4 to i8 addrspace(1)* addrspace(1)*
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %3, i8 addrspace(1)* %2, i8 addrspace(1)* addrspace(1)* %5)
  %6 = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @_CAO7default3barE)
  %7 = getelementptr i8, i8 addrspace(1)* %2, i64 24
  %8 = bitcast i8 addrspace(1)* %7 to i8 addrspace(1)* addrspace(1)*
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %6, i8 addrspace(1)* %2, i8 addrspace(1)* addrspace(1)* %8)
  musttail call void @finish(%Arr* %0)
  ret void
}

; CHECK-LABEL: define void @_CAFmusttailB(%Arr* %0)
; CHECK-NOT: _imp(
; CHECK: %1 = addrspacecast %Arr* %0 to %Arr addrspace(1)*
; CHECK: call i8 addrspace(1)* @llvm.cj.gcread.static.ref
; CHECK: musttail call void @finish(%Arr* %0)
; CHECK-NEXT: ret void
define void @_CAFmusttailB(%Arr* %0) gc "cangjie" {
bb0:
  %1 = addrspacecast %Arr* %0 to %Arr addrspace(1)*
  %2 = bitcast %Arr addrspace(1)* %1 to i8 addrspace(1)*
  %3 = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @_CAO7default3bazE)
  %4 = getelementptr i8, i8 addrspace(1)* %2, i64 16
  %5 = bitcast i8 addrspace(1)* %4 to i8 addrspace(1)* addrspace(1)*
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %3, i8 addrspace(1)* %2, i8 addrspace(1)* addrspace(1)* %5)
  %6 = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @_CAO7default3quxE)
  %7 = getelementptr i8, i8 addrspace(1)* %2, i64 24
  %8 = bitcast i8 addrspace(1)* %7 to i8 addrspace(1)* addrspace(1)*
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %6, i8 addrspace(1)* %2, i8 addrspace(1)* addrspace(1)* %8)
  musttail call void @finish(%Arr* %0)
  ret void
}

; CHECK-LABEL: define void @_CAFordinaryA(%Arr* %0)
; CHECK: call void @_CAFordinaryA_imp(%Arr* %0, i8 addrspace(1)** @_CAO7default3fooE, i8 addrspace(1)** @_CAO7default3barE)
; CHECK-NEXT: ret void
define void @_CAFordinaryA(%Arr* %0) gc "cangjie" {
bb0:
  %1 = addrspacecast %Arr* %0 to %Arr addrspace(1)*
  %2 = bitcast %Arr addrspace(1)* %1 to i8 addrspace(1)*
  %3 = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @_CAO7default3fooE)
  %4 = getelementptr i8, i8 addrspace(1)* %2, i64 16
  %5 = bitcast i8 addrspace(1)* %4 to i8 addrspace(1)* addrspace(1)*
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %3, i8 addrspace(1)* %2, i8 addrspace(1)* addrspace(1)* %5)
  %6 = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @_CAO7default3barE)
  %7 = getelementptr i8, i8 addrspace(1)* %2, i64 24
  %8 = bitcast i8 addrspace(1)* %7 to i8 addrspace(1)* addrspace(1)*
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %6, i8 addrspace(1)* %2, i8 addrspace(1)* addrspace(1)* %8)
  call void @finish(%Arr* %0)
  ret void
}

; CHECK-LABEL: define void @_CAFordinaryB(%Arr* %0)
; CHECK: call void @_CAFordinaryA_imp(%Arr* %0, i8 addrspace(1)** @_CAO7default3bazE, i8 addrspace(1)** @_CAO7default3quxE)
; CHECK-NEXT: ret void
define void @_CAFordinaryB(%Arr* %0) gc "cangjie" {
bb0:
  %1 = addrspacecast %Arr* %0 to %Arr addrspace(1)*
  %2 = bitcast %Arr addrspace(1)* %1 to i8 addrspace(1)*
  %3 = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @_CAO7default3bazE)
  %4 = getelementptr i8, i8 addrspace(1)* %2, i64 16
  %5 = bitcast i8 addrspace(1)* %4 to i8 addrspace(1)* addrspace(1)*
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %3, i8 addrspace(1)* %2, i8 addrspace(1)* addrspace(1)* %5)
  %6 = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @_CAO7default3quxE)
  %7 = getelementptr i8, i8 addrspace(1)* %2, i64 24
  %8 = bitcast i8 addrspace(1)* %7 to i8 addrspace(1)* addrspace(1)*
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %6, i8 addrspace(1)* %2, i8 addrspace(1)* addrspace(1)* %8)
  call void @finish(%Arr* %0)
  ret void
}

; CHECK-LABEL: define internal void @_CAFordinaryA_imp(%Arr* %0, i8 addrspace(1)** %slot0, i8 addrspace(1)** %slot1) local_unnamed_addr
; CHECK: call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** %slot0)
; CHECK: call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** %slot1)
; CHECK: call void @finish(%Arr* %0)
; CHECK-NEXT: ret void
