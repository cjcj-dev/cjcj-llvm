; RUN: opt -passes=cj-generic-intrinsic-opt --cangjie-pipeline -S < %s | FileCheck %s

; CHECK-LABEL: define void @edge_clean(
; CHECK: [[SRC:%.*]] = phi i8 addrspace(1)* [ %left.src, %left ], [ %right.src, %right ]
; CHECK: call void @llvm.cj.assign.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* [[SRC]], i8* %ti)
define void @edge_clean(i8 addrspace(1)* noalias %left.src, i8 addrspace(1)* noalias %right.src, i8 addrspace(1)* noalias %mid, i8 addrspace(1)* noalias %dst, i8 addrspace(1)* %unknown, i8* %ti, i1 %cond) {
entry:
  br i1 %cond, label %left, label %right
left:
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %mid, i8 addrspace(1)* %left.src, i8* %ti)
  br label %merge
right:
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %mid, i8 addrspace(1)* %right.src, i8* %ti)
  br label %merge
merge:
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* %mid, i8* %ti)
  ret void
}

; CHECK-LABEL: define void @edge_write(
; CHECK: [[SRC:%.*]] = phi i8 addrspace(1)* [ %mid, %left ], [ %right.src, %right ]
; CHECK: call void @llvm.cj.assign.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* [[SRC]], i8* %ti)
define void @edge_write(i8 addrspace(1)* noalias %left.src, i8 addrspace(1)* noalias %right.src, i8 addrspace(1)* noalias %mid, i8 addrspace(1)* noalias %dst, i8 addrspace(1)* %unknown, i8* %ti, i1 %cond) {
entry:
  br i1 %cond, label %left, label %right
left:
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %mid, i8 addrspace(1)* %left.src, i8* %ti)
  store i8 9, i8 addrspace(1)* %left.src
  br label %merge
right:
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %mid, i8 addrspace(1)* %right.src, i8* %ti)
  br label %merge
merge:
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* %mid, i8* %ti)
  ret void
}

; CHECK-LABEL: define void @merge_write(
; CHECK: [[SRC:%.*]] = phi i8 addrspace(1)* [ %mid, %left ], [ %right.src, %right ]
; CHECK: call void @llvm.cj.assign.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* [[SRC]], i8* %ti)
define void @merge_write(i8 addrspace(1)* noalias %left.src, i8 addrspace(1)* noalias %right.src, i8 addrspace(1)* noalias %mid, i8 addrspace(1)* noalias %dst, i8 addrspace(1)* %unknown, i8* %ti, i1 %cond) {
entry:
  br i1 %cond, label %left, label %right
left:
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %mid, i8 addrspace(1)* %left.src, i8* %ti)
  br label %merge
right:
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %mid, i8 addrspace(1)* %right.src, i8* %ti)
  br label %merge
merge:
  store i8 9, i8 addrspace(1)* %left.src
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* %mid, i8* %ti)
  ret void
}

; CHECK-LABEL: define void @other_edge_write(
; CHECK: [[SRC:%.*]] = phi i8 addrspace(1)* [ %left.src, %left ], [ %right.src, %right ]
; CHECK: call void @llvm.cj.assign.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* [[SRC]], i8* %ti)
define void @other_edge_write(i8 addrspace(1)* noalias %left.src, i8 addrspace(1)* noalias %right.src, i8 addrspace(1)* noalias %mid, i8 addrspace(1)* noalias %dst, i8 addrspace(1)* %unknown, i8* %ti, i1 %cond) {
entry:
  br i1 %cond, label %left, label %right
left:
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %mid, i8 addrspace(1)* %left.src, i8* %ti)
  store i8 9, i8 addrspace(1)* %right.src
  br label %merge
right:
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %mid, i8 addrspace(1)* %right.src, i8* %ti)
  br label %merge
merge:
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* %mid, i8* %ti)
  ret void
}

; CHECK-LABEL: define void @unknown_merge_write(
; CHECK-NOT: phi i8 addrspace(1)*
; CHECK: call void @llvm.cj.assign.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* %mid, i8* %ti)
define void @unknown_merge_write(i8 addrspace(1)* %left.src, i8 addrspace(1)* %right.src, i8 addrspace(1)* %mid, i8 addrspace(1)* %dst, i8 addrspace(1)* %unknown, i8* %ti, i1 %cond) {
entry:
  br i1 %cond, label %left, label %right
left:
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %mid, i8 addrspace(1)* %left.src, i8* %ti)
  br label %merge
right:
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %mid, i8 addrspace(1)* %right.src, i8* %ti)
  br label %merge
merge:
  store i8 9, i8 addrspace(1)* %unknown
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* %mid, i8* %ti)
  ret void
}

declare void @llvm.cj.assign.generic(i8 addrspace(1)* nocapture writeonly, i8 addrspace(1)* nocapture readonly, i8* nocapture readonly) argmemonly nounwind willreturn
