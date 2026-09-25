; RUN: opt -managed-abi-gate-report-only -passes=managed-abi-gate-verifier \
; RUN:   -disable-output < %s 2>&1 | FileCheck %s

declare i8 addrspace(1)* @llvm.cj.string.dedup.canonical(i8*, i8 addrspace(1)*)

define void @dedup_intrinsic(i8* %ti, i8 addrspace(1)* %candidate) gc "cangjie" {
entry:
  %backing = call i8 addrspace(1)* @llvm.cj.string.dedup.canonical(i8* %ti, i8 addrspace(1)* %candidate)
  ret void
}

; CHECK: [MANAGED_ABI_GATE] summary module={{.*}} calls_total=0 calls_passed=0 calls_reported=0 returns_total=0 returns_passed=0 returns_reported=0 nonheap_stores_total=0 nonheap_stores_passed=0 nonheap_stores_reported=0 calls_seen=1 calls_whitelisted=1 {{.*}} reason_unknown_call_result=0
