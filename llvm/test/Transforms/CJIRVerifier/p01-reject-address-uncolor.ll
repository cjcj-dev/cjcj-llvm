; RUN: not --crash opt -passes=cj-ir-verifier -disable-output < %s 2>&1 | FileCheck %s
; CHECK: P01: uncolor requires a loaded colored value, not a plain address
define i8 addrspace(1)* @double_uncolor(i8 addrspace(1)* %slot, i64 %shift) gc "cangjie" {
  %bits = ptrtoint i8 addrspace(1)* %slot to i64
  %shifted = lshr i64 %bits, %shift
  %result = inttoptr i64 %shifted to i8 addrspace(1)*
  ret i8 addrspace(1)* %result
}
