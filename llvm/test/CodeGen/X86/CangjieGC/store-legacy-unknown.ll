; RUN: llc --cangjie-pipeline -mtriple=x86_64 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; Legacy IR must not infer strong access from missing strength.
define void @legacy(i8 addrspace(1)* %value, i8 addrspace(1)* %base,
                    i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
; CHECK-LABEL: define void @legacy(
; CHECK-NOT: storeMedium
; CHECK: call void @CJ_MCC_WriteRefField(
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot)
  ret void
}
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
