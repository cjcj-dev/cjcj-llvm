; RUN: opt -S -cj-rewrite-statepoint < %s | FileCheck %s
; RUN: opt -S -passes=cj-rewrite-statepoint < %s | FileCheck %s

@global = addrspace(1) global i8 0

declare void @safepoint()
declare void @use_ptr(i8 addrspace(1)*) "gc-leaf-function"
declare void @use_vector(<2 x i8 addrspace(1)*>) "gc-leaf-function"
declare void @use_struct({ i8 addrspace(1)*, i64 }) "gc-leaf-function"

define void @phi_undef(i1 %condition, i8 addrspace(1)* %pointer) gc "cangjie" {
; CHECK-LABEL: @phi_undef(
; CHECK: merge:
; CHECK: %value = phi i8 addrspace(1)* [ null, %left ], [ %pointer, %right ]
; CHECK: @llvm.cj.gc.statepoint{{.*}}[ "gc-live"({{.*}}%value{{.*}}) ]
entry:
  br i1 %condition, label %left, label %right

left:
  br label %merge

right:
  br label %merge

merge:
  %value = phi i8 addrspace(1)* [ undef, %left ], [ %pointer, %right ]
  call void @safepoint()
  call void @use_ptr(i8 addrspace(1)* %value)
  ret void
}

define void @phi_poison(i1 %condition, i8 addrspace(1)* %pointer) gc "cangjie" {
; CHECK-LABEL: @phi_poison(
; CHECK: merge:
; CHECK: %value = phi i8 addrspace(1)* [ null, %left ], [ %pointer, %right ]
; CHECK: @llvm.cj.gc.statepoint{{.*}}[ "gc-live"({{.*}}%value{{.*}}) ]
entry:
  br i1 %condition, label %left, label %right

left:
  br label %merge

right:
  br label %merge

merge:
  %value = phi i8 addrspace(1)* [ poison, %left ], [ %pointer, %right ]
  call void @safepoint()
  call void @use_ptr(i8 addrspace(1)* %value)
  ret void
}

define void @select_poison(i1 %condition, i8 addrspace(1)* %pointer) gc "cangjie" {
; CHECK-LABEL: @select_poison(
; CHECK: %value = select i1 %condition, i8 addrspace(1)* %pointer, i8 addrspace(1)* null
; CHECK: @llvm.cj.gc.statepoint{{.*}}[ "gc-live"({{.*}}%value{{.*}}) ]
entry:
  %value = select i1 %condition, i8 addrspace(1)* %pointer, i8 addrspace(1)* poison
  call void @safepoint()
  call void @use_ptr(i8 addrspace(1)* %value)
  ret void
}

define void @vector_poison(i8 addrspace(1)* %pointer) gc "cangjie" {
; CHECK-LABEL: @vector_poison(
; CHECK: %value = insertelement <2 x i8 addrspace(1)*> zeroinitializer, i8 addrspace(1)* %pointer, i32 0
; CHECK: @llvm.cj.gc.statepoint{{.*}}[ "gc-live"({{.*}}%value{{.*}}) ]
entry:
  %value = insertelement <2 x i8 addrspace(1)*> poison, i8 addrspace(1)* %pointer, i32 0
  call void @safepoint()
  call void @use_vector(<2 x i8 addrspace(1)*> %value)
  ret void
}

define void @extract_undef() gc "cangjie" {
; CHECK-LABEL: @extract_undef(
; CHECK: %value = extractelement <2 x i8 addrspace(1)*> zeroinitializer, i32 1
; CHECK: @llvm.cj.gc.statepoint{{.*}}[ "gc-live"({{.*}}%value{{.*}}) ]
entry:
  %value = extractelement <2 x i8 addrspace(1)*> undef, i32 1
  call void @safepoint()
  call void @use_ptr(i8 addrspace(1)* %value)
  ret void
}

define void @bitcast_poison() gc "cangjie" {
; CHECK-LABEL: @bitcast_poison(
; CHECK: %value = bitcast <2 x i32 addrspace(1)*> zeroinitializer to <2 x i8 addrspace(1)*>
; CHECK: @llvm.cj.gc.statepoint{{.*}}[ "gc-live"({{.*}}%value{{.*}}) ]
entry:
  %value = bitcast <2 x i32 addrspace(1)*> poison to <2 x i8 addrspace(1)*>
  call void @safepoint()
  call void @use_vector(<2 x i8 addrspace(1)*> %value)
  ret void
}

define void @insertvalue_poison(i8 addrspace(1)* %pointer) gc "cangjie" {
; CHECK-LABEL: @insertvalue_poison(
; CHECK: %value = insertvalue { i8 addrspace(1)*, i64 } zeroinitializer, i8 addrspace(1)* %pointer, 0
; CHECK: @llvm.cj.gc.statepoint{{.*}}[ "gc-live"({{.*}}%value{{.*}}) ]
entry:
  %value = insertvalue { i8 addrspace(1)*, i64 } poison, i8 addrspace(1)* %pointer, 0
  call void @safepoint()
  call void @use_struct({ i8 addrspace(1)*, i64 } %value)
  ret void
}

define void @mixed_constant_vector() gc "cangjie" {
; CHECK-LABEL: @mixed_constant_vector(
; CHECK: %value = shufflevector <2 x i8 addrspace(1)*> <i8 addrspace(1)* @global, i8 addrspace(1)* null>, <2 x i8 addrspace(1)*> zeroinitializer, <2 x i32> <i32 0, i32 1>
entry:
  %value = shufflevector <2 x i8 addrspace(1)*> <i8 addrspace(1)* @global, i8 addrspace(1)* poison>, <2 x i8 addrspace(1)*> zeroinitializer, <2 x i32> <i32 0, i32 1>
  call void @safepoint()
  call void @use_vector(<2 x i8 addrspace(1)*> %value)
  ret void
}

define i8 addrspace(1)* @direct_constant() gc "cangjie" {
; CHECK-LABEL: @direct_constant(
; CHECK: @llvm.cj.gc.statepoint
; CHECK-NOT: "gc-live"
; CHECK: ret i8 addrspace(1)* undef
entry:
  call void @safepoint()
  ret i8 addrspace(1)* undef
}
