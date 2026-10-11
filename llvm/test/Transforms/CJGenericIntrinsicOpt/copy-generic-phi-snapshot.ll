; RUN: opt -passes=cj-generic-intrinsic-opt --cangjie-pipeline -S < %s | FileCheck %s

; CHECK-LABEL: define void @edge_clean(
; CHECK: [[SRC:%.*]] = phi i8 addrspace(1)* [ %right.src, %right ], [ %left.src, %left ]
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
; CHECK: [[SRC:%.*]] = phi i8 addrspace(1)* [ %right.src, %right ], [ %mid, %left ]
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
; CHECK: [[SRC:%.*]] = phi i8 addrspace(1)* [ %right.src, %right ], [ %mid, %left ]
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
; CHECK: [[SRC:%.*]] = phi i8 addrspace(1)* [ %right.src, %right ], [ %left.src, %left ]
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

; A backedge is outside the acyclic incoming-edge proof.
; CHECK-LABEL: define void @loop_snapshot(
; CHECK-NOT: phi i8 addrspace(1)*
; CHECK: call void @llvm.cj.assign.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* %mid, i8* %ti)
define void @loop_snapshot(i8 addrspace(1)* noalias %src, i8 addrspace(1)* noalias %mid, i8 addrspace(1)* noalias %dst, i8* %ti, i1 %cond) {
entry:
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %mid, i8 addrspace(1)* %src, i8* %ti)
  br label %loop
loop:
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* %mid, i8* %ti)
  br i1 %cond, label %body, label %exit
body:
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %mid, i8 addrspace(1)* %src, i8* %ti)
  br label %loop
exit:
  ret void
}

; This source dominates its incoming edge, but not the merge instruction.
; CHECK-LABEL: define void @edge_local_pointer(
; CHECK: [[LOCAL:%.*]] = phi i8 addrspace(1)* [ %right.src, %right ], [ %left.field, %left ]
; CHECK: call void @llvm.cj.assign.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* [[LOCAL]], i8* %ti)
define void @edge_local_pointer(i8 addrspace(1)* noalias %left.src, i8 addrspace(1)* noalias %right.src, i8 addrspace(1)* noalias %mid, i8 addrspace(1)* noalias %dst, i8* %ti, i1 %cond) {
entry:
  br i1 %cond, label %left, label %right
left:
  %left.field = getelementptr inbounds i8, i8 addrspace(1)* %left.src, i64 8
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %mid, i8 addrspace(1)* %left.field, i8* %ti)
  br label %merge
right:
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %mid, i8 addrspace(1)* %right.src, i8* %ti)
  br label %merge
merge:
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* %mid, i8* %ti)
  ret void
}

; A possibly aliased write on the left invalidates only that incoming snapshot.
; CHECK-LABEL: define void @unknown_edge_write(
; CHECK: [[UNKNOWN:%.*]] = phi i8 addrspace(1)* [ %right.src, %right ], [ %mid, %left ]
; CHECK: call void @llvm.cj.assign.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* [[UNKNOWN]], i8* %ti)
define void @unknown_edge_write(i8 addrspace(1)* %left.src, i8 addrspace(1)* %right.src, i8 addrspace(1)* noalias %mid, i8 addrspace(1)* noalias %dst, i8 addrspace(1)* %unknown, i8* %ti, i1 %cond) {
entry:
  br i1 %cond, label %left, label %right
left:
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %mid, i8 addrspace(1)* %left.src, i8* %ti)
  store i8 9, i8 addrspace(1)* %unknown
  br label %merge
right:
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %mid, i8 addrspace(1)* %right.src, i8* %ti)
  br label %merge
merge:
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* %mid, i8* %ti)
  ret void
}
