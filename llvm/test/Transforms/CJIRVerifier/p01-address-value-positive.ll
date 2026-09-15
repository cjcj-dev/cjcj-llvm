; RUN: opt -passes=cj-ir-verifier -disable-output < %s
; ZGC zAddress.inline.hpp:609: only the loaded colored value is uncolored.
define i8 addrspace(1)* @plain_address(i8 addrspace(1)* %address) gc "cangjie" {
  ret i8 addrspace(1)* %address
}
define i8 addrspace(1)* @loaded_value(i8 addrspace(1)* %slot_address, i64 %shift) gc "cangjie" {
  %slot = bitcast i8 addrspace(1)* %slot_address to i8 addrspace(1)* addrspace(1)*
  %value = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %slot, !cj.colored.value !0
  %bits = ptrtoint i8 addrspace(1)* %value to i64
  %address = lshr i64 %bits, %shift
  %plain = inttoptr i64 %address to i8 addrspace(1)*
  ret i8 addrspace(1)* %plain
}
!0 = !{}

define i8 addrspace(1)* @plain_argument_slot(i8 addrspace(1)** %slot) gc "cangjie" {
  %value = load i8 addrspace(1)*, i8 addrspace(1)** %slot
  ret i8 addrspace(1)* %value
}
@literal_slot = constant i8 addrspace(1)* null
define i8 addrspace(1)* @plain_literal_slot() gc "cangjie" {
  %value = load i8 addrspace(1)*, i8 addrspace(1)** @literal_slot
  ret i8 addrspace(1)* %value
}
