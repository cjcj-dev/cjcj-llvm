; RUN: opt -managed-abi-gate-report-only -passes=managed-abi-gate-verifier \
; RUN:   -disable-output < %s 2>&1 | FileCheck %s

declare i8 addrspace(1)* @managed_identity(i8 addrspace(1)*)

define i8 addrspace(1)* @plain_safe(i8 addrspace(1)* %plain) gc "cangjie" {
; CHECK-NOT: [MANAGED_ABI_GATE] report
; CHECK: [MANAGED_ABI_GATE] summary module={{.*}} calls_total=1 calls_passed=1 calls_reported=0 returns_total=1 returns_passed=1 returns_reported=0
entry:
  %ret = call i8 addrspace(1)* @managed_identity(i8 addrspace(1)* %plain)
  ret i8 addrspace(1)* %ret
}
