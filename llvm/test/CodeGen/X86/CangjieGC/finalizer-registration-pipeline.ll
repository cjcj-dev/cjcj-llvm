; RUN: opt -passes='cj-runtime-lowering,cj-rewrite-statepoint,verify' -S < %s > %t
; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu < %t | FileCheck %s --check-prefixes=X86,COMMON
; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu -enable-gc-fast-path=false -enable-cangjie-new-obj-fastpath=false < %t | FileCheck %s --check-prefixes=X86,COMMON
; RUN: llc --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu < %t | FileCheck %s --check-prefixes=ARM,COMMON
; RUN: llc --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu -enable-gc-fast-path=false -enable-cangjie-new-obj-fastpath=false < %t | FileCheck %s --check-prefixes=ARM,COMMON
; REQUIRES: x86-registered-target, aarch64-registered-target
;
; The statepoints are real opt output, consumed unchanged by llc. The one
; registration is an ordinary managed call after the ordinary allocation.
; Its exception table and stack map are emitted by the same backend pipeline.
target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare i8 addrspace(1)* @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)*) "gc-leaf-function"
declare i32 @__cj_personality_v0(...)

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
define i8 addrspace(1)* @construct_invoke(i8* %ti) gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* %ti, i32 16), !TrustedSize !0, !MallocType !1
  %registered = invoke i8 addrspace(1)* @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)* %obj) to label %normal unwind label %unwind
normal:
  ret i8 addrspace(1)* %registered
unwind:
  %ex = landingpad token cleanup
  resume token %ex
}

; COMMON: .gcc_except_table
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
!0 = !{}
!1 = !{!"HasFinalizer"}
