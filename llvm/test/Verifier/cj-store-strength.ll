; RUN: not opt -S < %s 2>&1 | FileCheck %s
; A strength is a static access decorator, not a runtime condition.
; CHECK: gcwrite.ref strength must be i32 0, 1, or 2

define void @bad_strength(i8 addrspace(1)* %value, i8 addrspace(1)* %base,
                          i8 addrspace(1)* addrspace(1)* %slot, i32 %strength) gc "cangjie" {
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot, i32 %strength)
  ret void
}
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)
