; RUN: opt -passes=cj-generic-intrinsic-opt --cangjie-pipeline -S < %s | FileCheck %s
; CHECK-LABEL: define void @nested_clean(
; CHECK: [[SRC:%.*]] = phi i8 addrspace(1)* [ %right.src, %right ], [ %mid, %join ]
; CHECK: call void @llvm.cj.assign.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* [[SRC]], i8* %ti)
; The existing MemoryPhi endpoint restriction retains the nested incoming
; snapshot. The independent ordinary right edge remains eligible to propagate.
; Nested edge endpoint is itself a MemoryPhi, rather than a MemoryDef.
define void @nested_clean(i8 addrspace(1)* noalias %one.src, i8 addrspace(1)* noalias %two.src, i8 addrspace(1)* noalias %right.src, i8 addrspace(1)* noalias %mid, i8 addrspace(1)* noalias %dst, i8* %ti, i1 %outer, i1 %inner) {
entry:
  br i1 %outer, label %left, label %right
left:
  br i1 %inner, label %one, label %two
one:
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %mid, i8 addrspace(1)* %one.src, i8* %ti)
  br label %join
two:
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %mid, i8 addrspace(1)* %two.src, i8* %ti)
  br label %join
join:
  br label %merge
right:
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %mid, i8 addrspace(1)* %right.src, i8* %ti)
  br label %merge
merge:
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* %mid, i8* %ti)
  ret void
}
declare void @llvm.cj.assign.generic(i8 addrspace(1)*, i8 addrspace(1)*, i8*)
