; RUN: opt -opaque-pointers=0 -passes=cj-generic-intrinsic-opt --cangjie-pipeline -S < %s | FileCheck %s
;
; The first instruction after a copy is a source write. The interval must
; begin at the actual copy read, never after that write.
; CHECK-LABEL: define void @assign_changed(
; CHECK: call void @llvm.cj.assign.generic(i8 addrspace(1)* %out, i8 addrspace(1)* %dst, i8* %ti)
define void @assign_changed(i8 addrspace(1)* noalias %src, i8 addrspace(1)* noalias %dst, i8 addrspace(1)* noalias %out, i8* %ti) {
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* %src, i8* %ti)
  store i8 9, i8 addrspace(1)* %src
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %out, i8 addrspace(1)* %dst, i8* %ti)
  ret void
}
; CHECK-LABEL: define void @assign_clean(
; CHECK: call void @llvm.cj.assign.generic(i8 addrspace(1)* %out, i8 addrspace(1)* %src, i8* %ti)
define void @assign_clean(i8 addrspace(1)* noalias %src, i8 addrspace(1)* noalias %dst, i8 addrspace(1)* noalias %out, i8* %ti, i8* noalias %other) {
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* %src, i8* %ti)
  store i8 9, i8* %other
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %out, i8 addrspace(1)* %dst, i8* %ti)
  ret void
}
; CHECK-LABEL: define void @read_generic_changed(
; CHECK: call void @llvm.cj.assign.generic(i8 addrspace(1)* %out, i8 addrspace(1)* %dst, i8* %ti)
define void @read_generic_changed(i8 addrspace(1)* noalias %src, i8 addrspace(1)* noalias %dst, i8 addrspace(1)* noalias %out, i32* %sizeptr) {
  %size = load i32, i32* %sizeptr
  %ti = bitcast i32* %sizeptr to i8*
  %from = getelementptr i8, i8 addrspace(1)* %src, i64 8
  call void @llvm.cj.gcread.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* %src, i8 addrspace(1)* %from, i32 %size)
  store i8 9, i8 addrspace(1)* %from
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %out, i8 addrspace(1)* %dst, i8* %ti)
  ret void
}
; CHECK-LABEL: define void @write_generic_changed(
; CHECK: call void @llvm.cj.gcread.generic(i8 addrspace(1)* %out, i8 addrspace(1)* %base, i8 addrspace(1)* %to, i32 %size)
define void @write_generic_changed(i8 addrspace(1)* noalias %src, i8 addrspace(1)* noalias %base, i8 addrspace(1)* noalias %out, i32* %sizeptr) {
  %size = load i32, i32* %sizeptr
  %to = getelementptr i8, i8 addrspace(1)* %base, i64 8
  call void @llvm.cj.gcwrite.generic(i8 addrspace(1)* %base, i8 addrspace(1)* %to, i8 addrspace(1)* %src, i32 %size)
  store i8 9, i8 addrspace(1)* %src
  call void @llvm.cj.gcread.generic(i8 addrspace(1)* %out, i8 addrspace(1)* %base, i8 addrspace(1)* %to, i32 %size)
  ret void
}
declare void @llvm.cj.assign.generic(i8 addrspace(1)* noalias nocapture writeonly, i8 addrspace(1)* noalias nocapture readonly, i8* noalias nocapture readonly) #0
declare void @llvm.cj.gcread.generic(i8 addrspace(1)* noalias nocapture writeonly, i8 addrspace(1)* nocapture readonly, i8 addrspace(1)* nocapture readonly, i32) #0
declare void @llvm.cj.gcwrite.generic(i8 addrspace(1)* nocapture, i8 addrspace(1)* nocapture writeonly, i8 addrspace(1)* noalias nocapture readonly, i32) #0
attributes #0 = { argmemonly mustprogress nounwind willreturn }
