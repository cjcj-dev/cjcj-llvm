; RUN: opt -managed-abi-gate-report-only -passes=managed-abi-gate-verifier \
; RUN:   -disable-output < %s 2>&1 | FileCheck %s

@heap_slot = addrspace(1) global i8 addrspace(1)* null

define i8 addrspace(1)* @coloured_return() gc "cangjie" {
; CHECK: [MANAGED_ABI_GATE] report reason=COLOURED_RETURN function=coloured_return index=0 state=COLOURED
; CHECK: [MANAGED_ABI_GATE] summary module={{.*}} calls_total=0 calls_passed=0 calls_reported=0 returns_total=1 returns_passed=0 returns_reported=1
entry:
  %coloured = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* @heap_slot
  ret i8 addrspace(1)* %coloured
}

