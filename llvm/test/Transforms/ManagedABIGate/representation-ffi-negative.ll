; RUN: opt -managed-abi-gate-report-only -passes=managed-abi-gate-verifier \
; RUN:   -disable-output < %s 2>&1 | FileCheck %s

declare i8 addrspace(1)* @ffi_without_contract() "cj2c"
declare void @managed_sink(i8 addrspace(1)*)

define void @ffi_negative() gc "cangjie" {
; CHECK: reason=UNKNOWN_CALL_RESULT function=ffi_negative callee=ffi_without_contract index=0 state=UNKNOWN
; CHECK: reason=UNKNOWN_ARGUMENT function=ffi_negative callee=managed_sink index=0 state=UNKNOWN
entry:
  %result = call i8 addrspace(1)* @ffi_without_contract()
  call void @managed_sink(i8 addrspace(1)* %result)
  ret void
}

