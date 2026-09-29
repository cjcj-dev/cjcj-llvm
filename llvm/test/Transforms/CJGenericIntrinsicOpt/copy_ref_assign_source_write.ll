; RUN: opt -passes=cj-generic-intrinsic-opt --cangjie-pipeline -S < %s | FileCheck %s --check-prefix=REF
; RUN: opt -passes=cj-generic-intrinsic-opt --cangjie-pipeline -S < %s | FileCheck %s
;
; The read block precedes the copy block in layout so the ref is processed
; before CopyOpt simplifies the intermediate copies. The copy block still
; dominates the read. Forwarding to mid is valid; forwarding through the
; overwritten src to origin is not.
; REF: %value = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %mid, i8 addrspace(1)* addrspace(1)* {{%[^ )]+}})
; CHECK: [[SUM:%.*]] = add i64 %read_offset, %offset
; CHECK-NEXT: [[OFF:%.*]] = sub i64 [[SUM]], 8
; CHECK-NEXT: [[PTR:%.*]] = getelementptr i8, i8 addrspace(1)* %mid, i64 [[OFF]]
; CHECK-NEXT: [[SLOT:%.*]] = bitcast i8 addrspace(1)* [[PTR]] to i8 addrspace(1)* addrspace(1)*
; CHECK-NEXT: %value = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %mid, i8 addrspace(1)* addrspace(1)* [[SLOT]])

define i8 addrspace(1)* @test(i8 addrspace(1)* noalias %origin, i8 addrspace(1)* noalias %src, i8 addrspace(1)* noalias %mid, i8 addrspace(1)* noalias %dst, i32* %sizeptr, i64 %offset, i64 %read_offset) {
entry:
  %size = load i32, i32* %sizeptr
  %ti = bitcast i32* %sizeptr to i8*
  %from_origin = getelementptr i8, i8 addrspace(1)* %origin, i64 16
  %from_mid = getelementptr i8, i8 addrspace(1)* %mid, i64 %offset
  br label %copy
read:
  %to = getelementptr i8, i8 addrspace(1)* %dst, i64 %read_offset
  %slot = bitcast i8 addrspace(1)* %to to i8 addrspace(1)* addrspace(1)*
  %value = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %dst, i8 addrspace(1)* addrspace(1)* %slot)
  ret i8 addrspace(1)* %value
copy:
  call void @llvm.cj.gcread.generic(i8 addrspace(1)* %src, i8 addrspace(1)* %origin, i8 addrspace(1)* %from_origin, i32 %size)
  call void @llvm.cj.assign.generic(i8 addrspace(1)* %mid, i8 addrspace(1)* %src, i8* %ti)
  call void @llvm.cj.gcread.generic(i8 addrspace(1)* %dst, i8 addrspace(1)* %mid, i8 addrspace(1)* %from_mid, i32 %size)
  store i8 0, i8 addrspace(1)* %src
  br label %read
}

declare void @llvm.cj.gcread.generic(i8 addrspace(1)* noalias nocapture writeonly, i8 addrspace(1)* nocapture readonly, i8 addrspace(1)* nocapture readonly, i32) #0
declare void @llvm.cj.assign.generic(i8 addrspace(1)* noalias nocapture writeonly, i8 addrspace(1)* noalias nocapture readonly, i8* noalias nocapture readonly) #0
declare void @llvm.cj.gcwrite.generic(i8 addrspace(1)* nocapture, i8 addrspace(1)* nocapture writeonly, i8 addrspace(1)* noalias nocapture readonly, i32) #0
declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* nocapture, i8 addrspace(1)* addrspace(1)* nocapture) #1
attributes #0 = { argmemonly mustprogress nounwind willreturn }
attributes #1 = { argmemonly nounwind readonly willreturn }
