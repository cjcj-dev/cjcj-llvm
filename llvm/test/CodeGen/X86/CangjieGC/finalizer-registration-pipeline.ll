; RUN: opt -passes='cj-runtime-lowering,cj-rewrite-statepoint,verify' -S < %s > %t
; RUN: FileCheck %s --check-prefix=ROOTS < %t
; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu < %t | FileCheck %s --check-prefixes=X86,COMMON
; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu -enable-gc-fast-path=false -enable-cangjie-new-obj-fastpath=false < %t | FileCheck %s --check-prefixes=X86,COMMON
; RUN: llc --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu < %t | FileCheck %s --check-prefixes=ARM,COMMON
; RUN: llc --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu -enable-gc-fast-path=false -enable-cangjie-new-obj-fastpath=false < %t | FileCheck %s --check-prefixes=ARM,COMMON
; REQUIRES: x86-registered-target, aarch64-registered-target
;
; The statepoints are real opt output, consumed unchanged by llc. The one
; registration is an ordinary managed call after the ordinary allocation.
; Its exception table and stack map are emitted by the same backend pipeline.
; The two EH shapes follow C@9dfd9f6f3803c862ef776fefd0be87b095296415:
; EmitCjStringLiteralIR.cj:190,208-220 marks the noinline materializer whose
; cleanup resumes; IRBuilder.cj:5454 and TerminatorExprDispatcher.cj use an
; ordinary catch/rethrow ending in throw + unreachable, without that marker.
; Full production binding: frontend-inputs/O0-3.ll, SHA256
; f6236fdff5188eec8a829e8e5e9defcba2cd4596c1b35eeddcf4964ab25cd80f.
; Its Object constructor registers, and its separate materializer resumes.
; This reduced cleanup fixture additionally keeps the registration receiver
; live on both edges; it is not a claim that ordinary constructors resume.
target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare i8 addrspace(1)* @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)*) "gc-leaf-function"
declare i32 @__cj_personality_v0(...)
declare void @observe(i8 addrspace(1)*) "gc-leaf-function"
declare i8* @llvm.cj.get.exception.wrapper()
declare i8 addrspace(1)* @llvm.cj.post.throw.exception(i8*)
declare void @llvm.cj.throw.exception(i8 addrspace(1)*)

; COMMON-LABEL: construct_call:
; X86: callq {{.*}}CJ_MCC_NewObject
; ARM: bl{{[[:space:]]+}}CJ_MCC_NewObject
; X86: callq {{.*}}CJ_MCC_OnFinalizerCreated
; ARM: bl{{[[:space:]]+}}CJ_MCC_OnFinalizerCreated
; COMMON-NOT: CJ_MCC_OnFinalizerCreated
; COMMON: ret
define i8 addrspace(1)* @construct_call(i8* %ti) gc "cangjie" {
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* %ti, i32 16), !TrustedSize !0, !MallocType !1
  %registered = call i8 addrspace(1)* @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)* %obj)
  ret i8 addrspace(1)* %registered
}

; COMMON-LABEL: construct_invoke:
; X86: callq {{.*}}CJ_MCC_NewObject
; ARM: bl{{[[:space:]]+}}CJ_MCC_NewObject
; X86: callq {{.*}}CJ_MCC_OnFinalizerCreated
; ARM: bl{{[[:space:]]+}}CJ_MCC_OnFinalizerCreated
; COMMON-NOT: CJ_MCC_OnFinalizerCreated
; COMMON: ret
; ROOTS-LABEL: define i8 addrspace(1)* @construct_invoke(
; ROOTS-SAME: #[[CLEANUP:[0-9]+]] gc "cangjie" personality
; ROOTS: [[ALLOC:%[^ ]+]] = call token {{.*}}@llvm.cj.gc.statepoint{{.*}}@CJ_MCC_NewObject,
; ROOTS: [[OBJ:%[^ ]+]] = call i8 addrspace(1)* @llvm.cj.gc.result.p1i8(token [[ALLOC]])
; ROOTS: [[INVOKE:%[^ ]+]] = invoke token {{.*}}@llvm.cj.gc.statepoint{{.*}}@CJ_MCC_OnFinalizerCreated, i32 1, i32 0, i8 addrspace(1)* [[OBJ]]) [ "gc-live"(i8 addrspace(1)* [[OBJ]]) ]
; ROOTS: normal:
; ROOTS: [[RESULT:%[^ ]+]] = call i8 addrspace(1)* @llvm.cj.gc.result.p1i8(token [[INVOKE]])
; ROOTS: [[NORMAL:%[^ ]+]] = call coldcc i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token [[INVOKE]], i32 0, i32 0)
; ROOTS: call void @observe(i8 addrspace(1)* [[NORMAL]])
; ROOTS: ret i8 addrspace(1)* [[RESULT]]
; ROOTS: unwind:
; ROOTS: [[PAD:%[^ ]+]] = landingpad token
; ROOTS: [[UNWIND:%[^ ]+]] = call coldcc i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token [[PAD]], i32 0, i32 0)
; ROOTS: call void @observe(i8 addrspace(1)* [[UNWIND]])
; ROOTS: resume token [[PAD]]
define i8 addrspace(1)* @construct_invoke(i8* %ti) noinline "cangjie" gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* %ti, i32 16), !TrustedSize !0, !MallocType !1
  %registered = invoke i8 addrspace(1)* @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)* %obj) to label %normal unwind label %unwind
normal:
  call void @observe(i8 addrspace(1)* %obj)
  ret i8 addrspace(1)* %registered
unwind:
  %ex = landingpad token cleanup
  call void @observe(i8 addrspace(1)* %obj)
  resume token %ex
}

; COMMON: .gcc_except_table
; COMMON-LABEL: construct_catch:
; X86: callq {{.*}}CJ_MCC_NewObject
; ARM: bl{{[[:space:]]+}}CJ_MCC_NewObject
; X86: callq {{.*}}CJ_MCC_OnFinalizerCreated
; ARM: bl{{[[:space:]]+}}CJ_MCC_OnFinalizerCreated
; COMMON-NOT: CJ_MCC_OnFinalizerCreated
; COMMON: ret
; X86: callq {{.*}}CJ_MCC_GetExceptionWrapper
; ARM: bl{{[[:space:]]+}}CJ_MCC_GetExceptionWrapper
; X86: callq {{.*}}CJ_MCC_PostThrowException
; ARM: bl{{[[:space:]]+}}CJ_MCC_PostThrowException
; X86: callq {{.*}}CJ_MCC_ThrowException
; ARM: bl{{[[:space:]]+}}CJ_MCC_ThrowException
; COMMON: .gcc_except_table
; ROOTS-LABEL: define i8 addrspace(1)* @construct_catch(i8* %ti, i1 %rethrow) gc "cangjie" personality
; ROOTS: [[CATCHALLOC:%[^ ]+]] = call token {{.*}}@llvm.cj.gc.statepoint{{.*}}@CJ_MCC_NewObject,
; ROOTS: [[CATCHOBJ:%[^ ]+]] = call i8 addrspace(1)* @llvm.cj.gc.result.p1i8(token [[CATCHALLOC]])
; ROOTS: [[CATCHINVOKE:%[^ ]+]] = invoke token {{.*}}@llvm.cj.gc.statepoint{{.*}}@CJ_MCC_OnFinalizerCreated, i32 1, i32 0, i8 addrspace(1)* [[CATCHOBJ]]) [ "gc-live"(i8 addrspace(1)* [[CATCHOBJ]]) ]
; ROOTS: normal:
; ROOTS: [[CATCHRESULT:%[^ ]+]] = call i8 addrspace(1)* @llvm.cj.gc.result.p1i8(token [[CATCHINVOKE]])
; ROOTS: [[CATCHNORMAL:%[^ ]+]] = call coldcc i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token [[CATCHINVOKE]], i32 0, i32 0)
; ROOTS: call void @observe(i8 addrspace(1)* [[CATCHNORMAL]])
; ROOTS: ret i8 addrspace(1)* [[CATCHRESULT]]
; ROOTS: unwind:
; ROOTS: [[CATCHPAD:%[^ ]+]] = landingpad token
; ROOTS-NEXT: catch i8* null
; ROOTS: [[CATCHROOT:%[^ ]+]] = call coldcc i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token [[CATCHPAD]], i32 0, i32 0)
; ROOTS: call void @observe(i8 addrspace(1)* [[CATCHROOT]])
; ROOTS: br i1 %rethrow, label %throw, label %caught
; ROOTS: caught:
; ROOTS: ret i8 addrspace(1)* [[CATCHROOT]]
; ROOTS: throw:
; ROOTS: %wrapper = call i8* @CJ_MCC_GetExceptionWrapper()
; ROOTS: %exception = call i8 addrspace(1)* @CJ_MCC_PostThrowException(i8* %wrapper)
; ROOTS: [[THROW:%[^ ]+]] = call token {{.*}}@llvm.cj.gc.statepoint(i64 0, i32 0, void (i8 addrspace(1)*)* @CJ_MCC_ThrowException, i32 1, i32 0, i8 addrspace(1)* %exception)
; ROOTS-NEXT: unreachable
; ROOTS-NEXT: }
define i8 addrspace(1)* @construct_catch(i8* %ti, i1 %rethrow) gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* %ti, i32 16), !TrustedSize !0, !MallocType !1
  %registered = invoke i8 addrspace(1)* @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)* %obj) to label %normal unwind label %unwind
normal:
  call void @observe(i8 addrspace(1)* %obj)
  ret i8 addrspace(1)* %registered
unwind:
  %ex = landingpad token catch i8* null
  call void @observe(i8 addrspace(1)* %obj)
  br i1 %rethrow, label %throw, label %caught
caught:
  ret i8 addrspace(1)* %obj
throw:
  %wrapper = call i8* @llvm.cj.get.exception.wrapper()
  %exception = call i8 addrspace(1)* @llvm.cj.post.throw.exception(i8* %wrapper)
  call void @llvm.cj.throw.exception(i8 addrspace(1)* %exception)
  unreachable
}

; COMMON-LABEL: plain_control:
; X86: callq {{.*}}CJ_MCC_NewObject
; ARM: bl{{[[:space:]]+}}CJ_MCC_NewObject
; COMMON-NOT: CJ_MCC_OnFinalizerCreated
; COMMON: ret
define i8 addrspace(1)* @plain_control(i8* %ti) gc "cangjie" {
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* %ti, i32 16), !TrustedSize !0
  ret i8 addrspace(1)* %obj
}

; COMMON: .cjmetadata.stackmap
; ROOTS: attributes #[[CLEANUP]] = { noinline "cangjie" }
!0 = !{}
!1 = !{!"HasFinalizer"}
