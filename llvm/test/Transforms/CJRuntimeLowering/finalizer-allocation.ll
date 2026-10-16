; RUN: opt -passes=cj-runtime-lowering -S < %s | FileCheck %s
; RUN: opt -cj-runtime-lowering -S < %s | FileCheck %s
;
; Registration belongs to the root constructor return, never allocation.
; A serialized MallocType marker must use the same allocator as a plain object.
; HotSpot Parse::call_register_finalizer, parse1.cpp:2467.

declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare i32 @__cj_personality_v0(...)

; CHECK-LABEL: define i8 addrspace(1)* @finalizer_call(
; CHECK: %obj = call noalias i8 addrspace(1)* @CJ_MCC_NewObject(i8* %ti, i32 40)
; CHECK-NOT: call {{.*}}@CJ_MCC_OnFinalizerCreated
; CHECK: ret i8 addrspace(1)* %obj
define i8 addrspace(1)* @finalizer_call(i8* %ti) {
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* %ti, i32 32), !MallocType !0, !TrustedSize !1
  ret i8 addrspace(1)* %obj
}

; CHECK-LABEL: define i8 addrspace(1)* @finalizer_invoke(
; CHECK: %obj = invoke noalias i8 addrspace(1)* @CJ_MCC_NewObject(i8* %ti, i32 40)
; CHECK-NEXT: to label %normal unwind label %unwind
; CHECK: normal:
; CHECK-NOT: call {{.*}}@CJ_MCC_OnFinalizerCreated
; CHECK: ret i8 addrspace(1)* %obj
; CHECK: unwind:
; CHECK: resume
define i8 addrspace(1)* @finalizer_invoke(i8* %ti) personality i32 (...)* @__cj_personality_v0 {
  %obj = invoke i8 addrspace(1)* @llvm.cj.malloc.object(i8* %ti, i32 32) to label %normal unwind label %unwind, !MallocType !0, !TrustedSize !1
normal:
  ret i8 addrspace(1)* %obj
unwind:
  %ex = landingpad { i8*, i32 } cleanup
  resume { i8*, i32 } %ex
}

; CHECK-LABEL: define i8 addrspace(1)* @plain_control(
; CHECK: %obj = call noalias i8 addrspace(1)* @CJ_MCC_NewObject(i8* %ti, i32 40)
; CHECK-NOT: call {{.*}}@CJ_MCC_OnFinalizerCreated
; CHECK: ret i8 addrspace(1)* %obj
define i8 addrspace(1)* @plain_control(i8* %ti) {
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* %ti, i32 32), !TrustedSize !1
  ret i8 addrspace(1)* %obj
}

; CHECK-LABEL: define i8 addrspace(1)* @pinned_call(
; CHECK: %{{[^ ]+}} = call noalias i8 addrspace(1)* @CJ_MCC_NewPinnedObject(i8* %ti, i32 168)
; CHECK-NOT: i1 false
; CHECK: ret i8 addrspace(1)*
define i8 addrspace(1)* @pinned_call(i8* %ti) {
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* %ti, i32 32), !MallocType !2
  ret i8 addrspace(1)* %obj
}

; CHECK-LABEL: define i8 addrspace(1)* @pinned_invoke(
; CHECK: invoke noalias i8 addrspace(1)* @CJ_MCC_NewPinnedObject(i8* %ti, i32 168)
; CHECK-NEXT: to label %normal unwind label %unwind
; CHECK: normal:
; CHECK: ret i8 addrspace(1)*
; CHECK: unwind:
; CHECK: resume
define i8 addrspace(1)* @pinned_invoke(i8* %ti) personality i32 (...)* @__cj_personality_v0 {
  %obj = invoke i8 addrspace(1)* @llvm.cj.malloc.object(i8* %ti, i32 32) to label %normal unwind label %unwind, !MallocType !3
normal:
  ret i8 addrspace(1)* %obj
unwind:
  %ex = landingpad { i8*, i32 } cleanup
  resume { i8*, i32 } %ex
}

; CHECK-LABEL: define i8 addrspace(1)* @weak_control(
; CHECK: call noalias i8 addrspace(1)* @CJ_MCC_NewWeakRefObject(i8* %ti, i32 40)
; CHECK: ret i8 addrspace(1)*
define i8 addrspace(1)* @weak_control(i8* %ti) {
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* %ti, i32 32), !MallocType !4, !TrustedSize !1
  ret i8 addrspace(1)* %obj
}

; CHECK: declare i8 addrspace(1)* @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)*) #[[REG:[0-9]+]]
; CHECK: declare noalias i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32) #[[ALLOC:[0-9]+]]
; CHECK: declare noalias i8 addrspace(1)* @CJ_MCC_NewPinnedObject(i8*, i32) #[[ALLOC]]
; CHECK: attributes #[[REG]] = { "cj-runtime" }
; CHECK: attributes #[[ALLOC]] = { argmemonly "cj-heapmalloc" "cj-runtime" }
!0 = !{!"HasFinalizer"}
!1 = !{}
!2 = !{!"Future"}
!3 = !{!"Mutex"}
!4 = !{!"WeakRef"}
