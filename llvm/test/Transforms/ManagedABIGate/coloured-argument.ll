; RUN: opt -managed-abi-gate-report-only -passes=managed-abi-gate-verifier \
; RUN:   -disable-output < %s 2>&1 | FileCheck %s

@heap_slot = addrspace(1) global i8 addrspace(1)* null

declare void @managed_sink(i8 addrspace(1)*)

define void @coloured_argument() gc "cangjie" {
; CHECK: [MANAGED_ABI_GATE] report reason=COLOURED_ARGUMENT function=coloured_argument callee=managed_sink index=0 state=COLOURED
; CHECK: [MANAGED_ABI_GATE] summary module={{.*}} calls_total=1 calls_passed=0 calls_reported=1
entry:
  %coloured = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* @heap_slot
  call void @managed_sink(i8 addrspace(1)* %coloured)
  ret void
}

