; RUN: opt -passes=cj-annotation-outline -verify-each -S %s | FileCheck %s
;
; Function parameter attributes are not part of the matching body instructions.
; Never turn a caller-owned destination into a byval copy, import sret/nonnull,
; or apply a different function contract. Matching ordinary destinations still
; share a helper. Even two byval members stay intact: forwarding with byval
; would introduce a second copy and change pointer identity.

%Arr = type { [32 x i8] }
declare i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** nocapture)
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
@_CAO7default3fooE = internal global i8 addrspace(1)* null
@_CAO7default3barE = internal global i8 addrspace(1)* null
@_CAO7default3bazE = internal global i8 addrspace(1)* null
@_CAO7default3quxE = internal global i8 addrspace(1)* null

; CHECK-LABEL: define void @_CAFbyvalA(%Arr* byval(%Arr) %0)
; CHECK-NOT: _imp(
; CHECK: %1 = addrspacecast %Arr* %0 to %Arr addrspace(1)*
; CHECK: call i8 addrspace(1)* @llvm.cj.gcread.static.ref
; CHECK: call void {{.*}}@llvm.cj.gcwrite.ref
; CHECK-NOT: _imp(
; CHECK: ret void
define void @_CAFbyvalA(%Arr* byval(%Arr) %0) gc "cangjie" {
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
  ret void
}

; CHECK-LABEL: define void @_CAFplainA(%Arr* %0)
; CHECK: call void @_CAFplainA_imp(%Arr* %0, i8 addrspace(1)** @_CAO7default3bazE, i8 addrspace(1)** @_CAO7default3quxE)
; CHECK-NEXT: ret void
define void @_CAFplainA(%Arr* %0) gc "cangjie" {
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
  ret void
}

; CHECK-LABEL: define void @_CAFbyvalB(%Arr* byval(%Arr) %0)
; CHECK-NOT: _imp(
; CHECK: %1 = addrspacecast %Arr* %0 to %Arr addrspace(1)*
; CHECK: call i8 addrspace(1)* @llvm.cj.gcread.static.ref
; CHECK: call void {{.*}}@llvm.cj.gcwrite.ref
; CHECK-NOT: _imp(
; CHECK: ret void
define void @_CAFbyvalB(%Arr* byval(%Arr) %0) gc "cangjie" {
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
  ret void
}

; CHECK-LABEL: define void @_CAFsretA(%Arr* sret(%Arr) %0)
; CHECK-NOT: _imp(
; CHECK: %1 = addrspacecast %Arr* %0 to %Arr addrspace(1)*
; CHECK: call i8 addrspace(1)* @llvm.cj.gcread.static.ref
; CHECK: call void {{.*}}@llvm.cj.gcwrite.ref
; CHECK-NOT: _imp(
; CHECK: ret void
define void @_CAFsretA(%Arr* sret(%Arr) %0) gc "cangjie" {
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
  ret void
}

; CHECK-LABEL: define void @_CAFnonnullA(%Arr* nonnull %0)
; CHECK-NOT: _imp(
; CHECK: %1 = addrspacecast %Arr* %0 to %Arr addrspace(1)*
; CHECK: call i8 addrspace(1)* @llvm.cj.gcread.static.ref
; CHECK: call void {{.*}}@llvm.cj.gcwrite.ref
; CHECK-NOT: _imp(
; CHECK: ret void
define void @_CAFnonnullA(%Arr* nonnull %0) gc "cangjie" {
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
  ret void
}

; CHECK-LABEL: define fastcc void @_CAFfastA(%Arr* %0)
; CHECK-NOT: _imp(
; CHECK: %1 = addrspacecast %Arr* %0 to %Arr addrspace(1)*
; CHECK: call i8 addrspace(1)* @llvm.cj.gcread.static.ref
; CHECK: call void {{.*}}@llvm.cj.gcwrite.ref
; CHECK-NOT: _imp(
; CHECK: ret void
define fastcc void @_CAFfastA(%Arr* %0) gc "cangjie" {
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
  ret void
}

; CHECK-LABEL: define void @_CAFnounwindA(%Arr* %0)
; CHECK-NOT: _imp(
; CHECK: %1 = addrspacecast %Arr* %0 to %Arr addrspace(1)*
; CHECK: call i8 addrspace(1)* @llvm.cj.gcread.static.ref
; CHECK: call void {{.*}}@llvm.cj.gcwrite.ref
; CHECK-NOT: _imp(
; CHECK: ret void
define void @_CAFnounwindA(%Arr* %0) nounwind gc "cangjie" {
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
  ret void
}

; CHECK-LABEL: define void @_CAFplainB(%Arr* %0)
; CHECK: call void @_CAFplainA_imp(%Arr* %0, i8 addrspace(1)** @_CAO7default3fooE, i8 addrspace(1)** @_CAO7default3barE)
; CHECK-NEXT: ret void
define void @_CAFplainB(%Arr* %0) gc "cangjie" {
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
  ret void
}

; CHECK-LABEL: define internal void @_CAFplainA_imp(%Arr* %0, i8 addrspace(1)** %slot0, i8 addrspace(1)** %slot1) local_unnamed_addr
; CHECK: call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** %slot0)
; CHECK: call void {{.*}}@llvm.cj.gcwrite.ref
; CHECK: call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** %slot1)
; CHECK: call void {{.*}}@llvm.cj.gcwrite.ref
; CHECK-NEXT: ret void
