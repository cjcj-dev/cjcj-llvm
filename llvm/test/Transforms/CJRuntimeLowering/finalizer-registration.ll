; RUN: opt -passes=cj-runtime-lowering -S < %s | FileCheck %s --check-prefix=LOWER
; RUN: opt -passes='cj-runtime-lowering,cj-rewrite-statepoint,verify' -S < %s | FileCheck %s --check-prefix=ROOTS
; RUN: opt -cj-runtime-lowering -cj-rewrite-statepoint -verify -S < %s | FileCheck %s --check-prefix=ROOTS
;
; Existing declarations AND call sites can carry stale serialized leaf/purity
; attributes. Registration captures its input, may GC and may throw. The result
; and the relocated receiver must both reach their actual downstream uses.
; HotSpot parse1.cpp:2467-2472 uses RC_NO_LEAF and make_slow_call_ex.
target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
declare noalias i8 addrspace(1)* @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)* nocapture readonly returned) #0
declare void @observe(i8 addrspace(1)*) "gc-leaf-function"
declare i32 @__cj_personality_v0(...)

; LOWER: declare i8 addrspace(1)* @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)*) #[[REG:[0-9]+]]
; LOWER-LABEL: define i8 addrspace(1)* @register_call(
; LOWER: %registered = call i8 addrspace(1)* @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)* %obj){{$}}
; ROOTS-LABEL: define i8 addrspace(1)* @register_call(
; ROOTS: [[TOKEN:%[^ ]+]] = call token {{.*}}@llvm.cj.gc.statepoint{{.*}}@CJ_MCC_OnFinalizerCreated, i32 1, i32 0, i8 addrspace(1)* %obj)
; ROOTS: [[RESULT:%[^ ]+]] = call i8 addrspace(1)* @llvm.cj.gc.result.p1i8(token [[TOKEN]])
; ROOTS: [[RELOC:%[^ ]+]] = call coldcc i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token [[TOKEN]], i32 0, i32 0)
; ROOTS: %same = icmp eq i8 addrspace(1)* [[RESULT]], [[RELOC]]
; ROOTS: %chosen = select i1 %same, i8 addrspace(1)* [[RESULT]], i8 addrspace(1)* [[RELOC]]
; ROOTS: ret i8 addrspace(1)* %chosen
define i8 addrspace(1)* @register_call(i8 addrspace(1)* %obj) gc "cangjie" {
  %registered = call noalias i8 addrspace(1)* @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)* nocapture readonly returned %obj) #0
  %same = icmp eq i8 addrspace(1)* %registered, %obj
  %chosen = select i1 %same, i8 addrspace(1)* %registered, i8 addrspace(1)* %obj
  ret i8 addrspace(1)* %chosen
}

; LOWER-LABEL: define i8 addrspace(1)* @register_invoke(
; LOWER: %registered = invoke i8 addrspace(1)* @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)* %obj){{$}}
; LOWER-NEXT: to label %normal unwind label %unwind
; ROOTS-LABEL: define i8 addrspace(1)* @register_invoke(
; ROOTS: [[INVOKE:%[^ ]+]] = invoke token {{.*}}@llvm.cj.gc.statepoint{{.*}}@CJ_MCC_OnFinalizerCreated, i32 1, i32 0, i8 addrspace(1)* %obj)
; ROOTS: to label %normal unwind label %unwind
; ROOTS: normal:
; ROOTS: [[INVOKERES:%[^ ]+]] = call i8 addrspace(1)* @llvm.cj.gc.result.p1i8(token [[INVOKE]])
; ROOTS: [[NORMALROOT:%[^ ]+]] = call coldcc i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token [[INVOKE]], i32 0, i32 0)
; ROOTS: call void @observe(i8 addrspace(1)* [[NORMALROOT]])
; ROOTS: ret i8 addrspace(1)* [[INVOKERES]]
; ROOTS: unwind:
; ROOTS: [[PAD:%[^ ]+]] = landingpad token
; ROOTS: [[UNWINDROOT:%[^ ]+]] = call coldcc i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token [[PAD]], i32 0, i32 0)
; ROOTS: call void @observe(i8 addrspace(1)* [[UNWINDROOT]])
; ROOTS: ret i8 addrspace(1)* [[UNWINDROOT]]
define i8 addrspace(1)* @register_invoke(i8 addrspace(1)* %obj) gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
  %registered = invoke noalias i8 addrspace(1)* @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)* nocapture readonly returned %obj) #0 to label %normal unwind label %unwind
normal:
  call void @observe(i8 addrspace(1)* %obj)
  ret i8 addrspace(1)* %registered
unwind:
  %ex = landingpad token cleanup
  call void @observe(i8 addrspace(1)* %obj)
  ret i8 addrspace(1)* %obj
}

; LOWER-LABEL: define i8 addrspace(1)* @plain_control(
; LOWER: call void @observe(i8 addrspace(1)* %obj)
; LOWER: ret i8 addrspace(1)* %obj
; ROOTS-LABEL: define i8 addrspace(1)* @plain_control(
; ROOTS-NOT: @llvm.cj.gc.statepoint
; ROOTS: call void @observe(i8 addrspace(1)* %obj)
; ROOTS: ret i8 addrspace(1)* %obj
define i8 addrspace(1)* @plain_control(i8 addrspace(1)* %obj) gc "cangjie" {
  call void @observe(i8 addrspace(1)* %obj)
  ret i8 addrspace(1)* %obj
}

; LOWER: attributes #[[REG]] = { "cj-runtime" }
attributes #0 = { argmemonly nofree nosync nounwind readonly willreturn "cj-heapmalloc" "gc-leaf-function" }
