; RUN: not --crash opt -passes=cj-ir-verifier -disable-output < %s 2>&1 | FileCheck %s
; CHECK: P01: plain local root must not use a colored static read barrier
define i8 addrspace(1)* @wrong_argument_read(i8 addrspace(1)** %slot) gc "cangjie" {
  %result = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** %slot)
  ret i8 addrspace(1)* %result
}
declare i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)**)
