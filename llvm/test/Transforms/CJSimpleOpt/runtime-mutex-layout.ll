; RUN: opt -passes=cj-simple-opt -S < %s | FileCheck %s
; The emitted stub must address owner/count/state in the paired runtime layout.
; CHECK-LABEL: define internal void @CJMutexLockStub(
; CHECK: getelementptr i8, i8 addrspace(1)* %{{.*}}, i32 8
; CHECK: getelementptr i8, i8 addrspace(1)* %{{.*}}, i32 16
; CHECK: getelementptr i8, i8 addrspace(1)* %{{.*}}, i32 24
; CHECK: cmpxchg i64 addrspace(1)* %{{.*}}, i64 0, i64 4 seq_cst seq_cst
; CHECK: call cangjiegccc i64 @GetCJThreadIdForMutexOpt()
; CHECK: store atomic i64 %{{.*}}, i64 addrspace(1)* %{{.*}} release
; CHECK: call void @CJ_MCC_MutexLockSlowPath(

define void @lock(i8 addrspace(1)* %mutex) gc "cangjie" {
  call void @CJ_MCC_MutexLock(i8 addrspace(1)* %mutex)
  ret void
}
declare void @CJ_MCC_MutexLock(i8 addrspace(1)*)
