; RUN: opt -managed-abi-gate-report-only -passes=managed-abi-gate-verifier \
; RUN:   -disable-output < %s 2>&1 | FileCheck %s

@heap_slot = addrspace(1) global i8 addrspace(1)* null

define void @coloured_nonheap_store() gc "cangjie" {
; CHECK: [MANAGED_ABI_GATE] report reason=COLOURED_NONHEAP_STORE function=coloured_nonheap_store index=0 state=COLOURED
; CHECK: [MANAGED_ABI_GATE] summary module={{.*}} calls_total=0 calls_passed=0 calls_reported=0 returns_total=0 returns_passed=0 returns_reported=0 nonheap_stores_total=1 nonheap_stores_passed=0 nonheap_stores_reported=1
entry:
  %root = alloca i8 addrspace(1)*, align 8
  %coloured = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* @heap_slot
  store i8 addrspace(1)* %coloured, i8 addrspace(1)** %root, align 8
  ret void
}
