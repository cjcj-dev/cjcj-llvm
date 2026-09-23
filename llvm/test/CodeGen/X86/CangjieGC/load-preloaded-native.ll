; RUN: llc --cangjie-pipeline -mtriple=x86_64 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=aarch64 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; Native globals and atomic accessors retain their accessor protocol.
@root = global i8 addrspace(1)* null

define i8 addrspace(1)* @static_read() gc "cangjie" {
; CHECK-LABEL: define i8 addrspace(1)* @static_read(
; CHECK: gcMarked:
; CHECK-NEXT: [[STATIC:%[^ ]+]] = call i8 addrspace(1)* @CJ_MCC_ReadStaticRef(i8 addrspace(1)** @root)
; CHECK: loadFinish:
; CHECK: phi i8 addrspace(1)* {{.*}}[ [[STATIC]], %gcMarked ]
  %value = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @root)
  ret i8 addrspace(1)* %value
}

define i8 addrspace(1)* @atomic_read(i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
; CHECK-LABEL: define i8 addrspace(1)* @atomic_read(
; CHECK: load atomic i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %slot seq_cst
; CHECK: gcMarked:
; CHECK-NEXT: [[ATOMIC:%[^ ]+]] = call i8 addrspace(1)* @CJ_MCC_AtomicReadReference(i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot, i32 5)
; CHECK: loadFinish:
; CHECK: phi i8 addrspace(1)* {{.*}}[ [[ATOMIC]], %gcMarked ]
  %value = call i8 addrspace(1)* @llvm.cj.atomic.load(i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot, i32 5)
  ret i8 addrspace(1)* %value
}
declare i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)**)
declare i8 addrspace(1)* @llvm.cj.atomic.load(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, i32)
