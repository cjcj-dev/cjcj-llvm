; RUN: opt -passes=cj-generic-intrinsic-opt --cangjie-pipeline -S < %s | FileCheck %s
; N0: two predecessors with the same reaching memory state; no MemoryPhi.

; CHECK-LABEL: define {{.*}} @test(
; CHECK: %value = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %dst, i8 addrspace(1)* addrspace(1)* %slot)

@unrelated = global i32 0

define i8 addrspace(1)* @test(i8 addrspace(1)* noalias %src, i8 addrspace(1)* noalias %dst, i32* %sizeptr, i64 %offset, i64 %read_offset, i1 %cond) {
entry:
  %size = load i32, i32* %sizeptr
  %from = getelementptr i8, i8 addrspace(1)* %src, i64 %offset
  call void @llvm.cj.gcread.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* %src, i8 addrspace(1)* %from, i32 %size)
  br i1 %cond, label %left, label %right
left:
  br label %read
right:
  br label %read
read:
  %to = getelementptr i8, i8 addrspace(1)* %dst, i64 %read_offset
  %slot = bitcast i8 addrspace(1)* %to to i8 addrspace(1)* addrspace(1)*
  %value = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %dst, i8 addrspace(1)* addrspace(1)* %slot)
  ret i8 addrspace(1)* %value
}

declare void @llvm.cj.gcread.generic(i8 addrspace(1)* noalias nocapture writeonly, i8 addrspace(1)* nocapture readonly, i8 addrspace(1)* nocapture readonly, i32) #0
declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* nocapture, i8 addrspace(1)* addrspace(1)* nocapture) #1
attributes #0 = { argmemonly mustprogress nounwind willreturn }
attributes #1 = { argmemonly nounwind readonly willreturn }
