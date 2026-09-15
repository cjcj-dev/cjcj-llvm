; RUN: not --crash opt -passes=cj-ir-verifier -disable-output < %s 2>&1 | FileCheck %s
; CHECK: P01: colored field value cannot be used as an address
define i8 @use_colored_address(i8 addrspace(1)* %slot_address) gc "cangjie" {
  %slot = bitcast i8 addrspace(1)* %slot_address to i8 addrspace(1)* addrspace(1)*
  %value = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %slot, !cj.colored.value !0
  %result = load i8, i8 addrspace(1)* %value
  ret i8 %result
}
!0 = !{}
