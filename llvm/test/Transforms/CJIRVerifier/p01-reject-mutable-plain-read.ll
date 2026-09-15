; RUN: not --crash opt -passes=cj-ir-verifier -disable-output < %s 2>&1 | FileCheck %s
; CHECK: Need read static barrier!
@mutable_slot = global i8 addrspace(1)* null
define i8 addrspace(1)* @wrong_mutable_read() gc "cangjie" {
  %value = load i8 addrspace(1)*, i8 addrspace(1)** @mutable_slot
  ret i8 addrspace(1)* %value
}
