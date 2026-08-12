; RUN: opt -managed-abi-gate-report-only -passes=managed-abi-gate-verifier \
; RUN:   -disable-output < %s 2>&1 | FileCheck %s

@root_slot = global i8 addrspace(1)* null
@heap_slot = addrspace(1) global i8 addrspace(1)* null

declare void @managed_sink(i8 addrspace(1)*)

define void @argument_contract() gc "cangjie" {
; CHECK-NOT: reason=UNKNOWN_ARGUMENT function=argument_contract
; CHECK: reason=COLOURED_ARGUMENT function=argument_contract callee=managed_sink index=0 state=COLOURED
; CHECK: reason_coloured_argument=1
; CHECK-SAME: reason_plain_unsafe_argument=0
; CHECK-SAME: reason_unknown_argument=0
entry:
  %unknown = load i8 addrspace(1)*, i8 addrspace(1)** @root_slot
  call void @managed_sink(
      i8 addrspace(1)* "cj.repr.arg"="plain_safe" %unknown)
  %coloured = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* @heap_slot
  call void @managed_sink(
      i8 addrspace(1)* "cj.repr.arg"="plain_safe" %coloured)
  ret void
}
