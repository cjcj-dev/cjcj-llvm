; RUN: opt -passes='cj-runtime-lowering,function(gvn,dse)' -S < %s | FileCheck %s
; RUN: opt -cj-runtime-lowering -gvn -dse -S < %s | FileCheck %s
;
; Normal managed call effects must carry registration's capture and memory
; semantics, without a finalizer-specific allocation exemption in GVN or DSE.
; parse1.cpp:2467-2472 uses TypePtr::BOTTOM memory and an exceptional slow call.
declare noalias i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32) #0
declare noalias i8 addrspace(1)* @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)* nocapture) #1

; CHECK-LABEL: define i64 @registered_read(
; CHECK: store i64 17, i64 addrspace(1)* %slot
; CHECK: call i8 addrspace(1)* @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)* %obj)
; CHECK: %loaded = load i64, i64 addrspace(1)* %slot
; CHECK: ret i64 %loaded
define i64 @registered_read(i8* %ti) {
  %obj = call noalias i8 addrspace(1)* @CJ_MCC_NewObject(i8* %ti, i32 16)
  %field = getelementptr i8, i8 addrspace(1)* %obj, i64 8
  %slot = bitcast i8 addrspace(1)* %field to i64 addrspace(1)*
  store i64 17, i64 addrspace(1)* %slot
  %registered = call noalias i8 addrspace(1)* @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)* nocapture %obj) #1
  %loaded = load i64, i64 addrspace(1)* %slot
  ret i64 %loaded
}

; CHECK-LABEL: define void @registered_capture(
; CHECK: store i64 17, i64 addrspace(1)* %slot
; CHECK: call i8 addrspace(1)* @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)* %obj)
; CHECK: store i64 18, i64 addrspace(1)* %slot
; CHECK: ret void
define void @registered_capture(i8* %ti) {
  %obj = call noalias i8 addrspace(1)* @CJ_MCC_NewObject(i8* %ti, i32 16)
  %field = getelementptr i8, i8 addrspace(1)* %obj, i64 8
  %slot = bitcast i8 addrspace(1)* %field to i64 addrspace(1)*
  store i64 17, i64 addrspace(1)* %slot
  %registered = call noalias i8 addrspace(1)* @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)* nocapture %obj) #1
  store i64 18, i64 addrspace(1)* %slot
  ret void
}

; CHECK-LABEL: define void @plain_control(
; CHECK-NOT: store
; CHECK-NOT: @CJ_MCC_OnFinalizerCreated
; CHECK: ret void
define void @plain_control(i8* %ti) {
  %obj = call noalias i8 addrspace(1)* @CJ_MCC_NewObject(i8* %ti, i32 16)
  %field = getelementptr i8, i8 addrspace(1)* %obj, i64 8
  %slot = bitcast i8 addrspace(1)* %field to i64 addrspace(1)*
  store i64 17, i64 addrspace(1)* %slot
  ret void
}
attributes #0 = { argmemonly "cj-heapmalloc" "cj-runtime" }
attributes #1 = { argmemonly nofree nosync nounwind readnone willreturn "cj-heapmalloc" "gc-leaf-function" }
