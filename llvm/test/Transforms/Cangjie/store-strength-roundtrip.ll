; RUN: opt -S -passes='cj-gcinstr-replace,cj-gcinstr-restore' < %s | FileCheck %s
; The static access decorator must survive the product store optimization path.
define void @weak(i8 addrspace(1)* %value, i8 addrspace(1)* %base,
                  i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
; CHECK-LABEL: define void @weak(
; CHECK: call void {{.*}}@llvm.cj.gcwrite.ref({{.*}}i32 2)
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot, i32 2)
  ret void
}
define void @legacy(i8 addrspace(1)* %value, i8 addrspace(1)* %base,
                    i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
; CHECK-LABEL: define void @legacy(
; CHECK: call void {{.*}}@llvm.cj.gcwrite.ref({{.*}}%slot)
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot)
  ret void
}
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)
