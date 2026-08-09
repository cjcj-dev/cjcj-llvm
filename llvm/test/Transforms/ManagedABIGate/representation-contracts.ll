; RUN: opt -managed-abi-gate-report-only -passes=managed-abi-gate-verifier \
; RUN:   -disable-output < %s 2>&1 | FileCheck %s

%S = type { i8 addrspace(1)* }

declare i32 @__gxx_personality_v0(...)
declare void @on_unwind()
declare "cj.repr.ret"="plain_safe" i8 addrspace(1)* @direct_result()
declare void @direct_sret(%S* noalias sret(%S) "cj.repr.sret"="plain_safe")

define void @contracts(
    i8 addrspace(1)* ()* %indirect_result,
    void (%S*)* %indirect_sret) gc "cangjie"
    personality i8* bitcast (i32 (...)* @__gxx_personality_v0 to i8*) {
; CHECK-NOT: [MANAGED_ABI_GATE] report
; CHECK: [MANAGED_ABI_GATE] summary module={{.*}} calls_total=7 calls_passed=7 calls_reported=0
; CHECK-SAME: reason_sret_unproven=0
entry:
  %direct = call "cj.repr.ret"="plain_safe" i8 addrspace(1)* @direct_result()
  %indirect = call "cj.repr.ret"="plain_safe" i8 addrspace(1)* %indirect_result()
  %direct_out = alloca %S, align 8
  call void @direct_sret(%S* noalias sret(%S) "cj.repr.sret"="plain_safe" %direct_out)
  %indirect_out = alloca %S, align 8
  call void %indirect_sret(%S* noalias sret(%S) "cj.repr.sret"="plain_safe" %indirect_out)
  %generic_out = alloca %S, align 8
  call void %indirect_sret(%S* noalias sret(%S) "cj.repr.sret"="plain_safe" %generic_out)
  %invoke_out = alloca %S, align 8
  invoke void %indirect_sret(%S* noalias sret(%S) "cj.repr.sret"="plain_safe" %invoke_out)
      to label %normal unwind label %unwind

normal:
  ret void

unwind:
  %landing = landingpad { i8*, i32 } cleanup
  call void @on_unwind()
  resume { i8*, i32 } %landing
}
