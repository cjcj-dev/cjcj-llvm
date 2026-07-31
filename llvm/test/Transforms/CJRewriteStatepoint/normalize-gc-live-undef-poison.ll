; RUN: opt -S -cj-rewrite-statepoint < %s | FileCheck %s
; RUN: opt -S -passes=cj-rewrite-statepoint < %s | FileCheck %s

@global = addrspace(1) global i8 0

declare void @safepoint()
declare void @use_ptr(i8 addrspace(1)*) "gc-leaf-function"

; cjcj keeps managed-ref aggregates in memory for struct-live and does not emit managed-ref vectors; gc-live carriers below are scalar pointers.

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

define i8 addrspace(1)* @phi_only_undefined(i1 %condition) gc "cangjie" {
; CHECK-LABEL: @phi_only_undefined(
; CHECK: merge:
; CHECK: %value = phi i8 addrspace(1)* [ null, %left ], [ null, %right ]
; CHECK: @llvm.cj.gc.statepoint
; CHECK-NOT: "gc-live"
; CHECK: ret i8 addrspace(1)* %value
entry:
  br i1 %condition, label %left, label %right

left:
  br label %merge

right:
  br label %merge

merge:
  %value = phi i8 addrspace(1)* [ undef, %left ], [ poison, %right ]
  call void @safepoint()
  ret i8 addrspace(1)* %value
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

define void @gep_poison() gc "cangjie" {
; CHECK-LABEL: @gep_poison(
; CHECK: %value = getelementptr i8, i8 addrspace(1)* null, i64 0
; CHECK: @llvm.cj.gc.statepoint{{.*}}[ "gc-live"({{.*}}%value{{.*}}) ]
entry:
  %value = getelementptr i8, i8 addrspace(1)* poison, i64 0
  call void @safepoint()
  call void @use_ptr(i8 addrspace(1)* %value)
  ret void
}

define void @extract_undef() gc "cangjie" {
; CHECK-LABEL: @extract_undef(
; CHECK: %value = extractvalue { i8 addrspace(1)*, i64 } zeroinitializer, 0
; CHECK: @llvm.cj.gc.statepoint{{.*}}[ "gc-live"({{.*}}%value{{.*}}) ]
entry:
  %value = extractvalue { i8 addrspace(1)*, i64 } undef, 0
  call void @safepoint()
  call void @use_ptr(i8 addrspace(1)* %value)
  ret void
}

define void @bitcast_poison() gc "cangjie" {
; CHECK-LABEL: @bitcast_poison(
; CHECK: %value = bitcast i32 addrspace(1)* null to i8 addrspace(1)*
; CHECK: @llvm.cj.gc.statepoint{{.*}}[ "gc-live"({{.*}}%value{{.*}}) ]
entry:
  %value = bitcast i32 addrspace(1)* poison to i8 addrspace(1)*
  call void @safepoint()
  call void @use_ptr(i8 addrspace(1)* %value)
  ret void
}

define void @insertvalue_poison(i8 addrspace(1)* %pointer) gc "cangjie" {
; CHECK-LABEL: @insertvalue_poison(
; CHECK: %aggregate = insertvalue { i8 addrspace(1)*, i64 } zeroinitializer, i8 addrspace(1)* %pointer, 0
; CHECK: @llvm.cj.gc.statepoint{{.*}}[ "gc-live"({{.*}}%value{{.*}}) ]
entry:
  %aggregate = insertvalue { i8 addrspace(1)*, i64 } poison, i8 addrspace(1)* %pointer, 0
  %value = extractvalue { i8 addrspace(1)*, i64 } %aggregate, 0
  call void @safepoint()
  call void @use_ptr(i8 addrspace(1)* %value)
  ret void
}

define void @mixed_constant_struct() gc "cangjie" {
; CHECK-LABEL: @mixed_constant_struct(
; CHECK: %value = extractvalue { i8 addrspace(1)*, i8 addrspace(1)* } { i8 addrspace(1)* @global, i8 addrspace(1)* null }, 1
; CHECK: @llvm.cj.gc.statepoint{{.*}}[ "gc-live"({{.*}}%value{{.*}}) ]
entry:
  %value = extractvalue { i8 addrspace(1)*, i8 addrspace(1)* } { i8 addrspace(1)* @global, i8 addrspace(1)* poison }, 1
  call void @safepoint()
  call void @use_ptr(i8 addrspace(1)* %value)
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
