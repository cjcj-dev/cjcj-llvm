; RUN: llc --cangjie-pipeline -mtriple=x86_64 -print-after=cj-barrier-lowering \
; RUN:   -o /dev/null < %s 2>&1 | FileCheck %s

define i8 addrspace(1)* @read_ref(i8 addrspace(1)* %obj,
                                  i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
; CHECK-LABEL: define i8 addrspace(1)* @read_ref(
; CHECK: [[REF_INT:%.*]] = ptrtoint i8 addrspace(1)* {{%.*}} to i64
; CHECK: gcNoMarked:
; CHECK-NEXT: [[REF_ADDRESS:%.*]] = and i64 [[REF_INT]], 281474976710655
; CHECK-NEXT: [[REF_UNCOLORED:%.*]] = inttoptr i64 [[REF_ADDRESS]] to i8 addrspace(1)*
entry:
  %ref = call i8 addrspace(1)* @llvm.cj.gcread.ref(
      i8 addrspace(1)* %obj, i8 addrspace(1)* addrspace(1)* %field)
  ret i8 addrspace(1)* %ref
}

define i8 addrspace(1)* @atomic_read_ref(i8 addrspace(1)* %obj,
                                         i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
; CHECK-LABEL: define i8 addrspace(1)* @atomic_read_ref(
; CHECK: [[ATOMIC_INT:%.*]] = ptrtoint i8 addrspace(1)* {{%.*}} to i64
; CHECK: gcNoMarked:
; CHECK-NEXT: [[ATOMIC_ADDRESS:%.*]] = and i64 [[ATOMIC_INT]], 281474976710655
; CHECK-NEXT: [[ATOMIC_UNCOLORED:%.*]] = inttoptr i64 [[ATOMIC_ADDRESS]] to i8 addrspace(1)*
entry:
  %ref = call i8 addrspace(1)* @llvm.cj.atomic.load(
      i8 addrspace(1)* %obj, i8 addrspace(1)* addrspace(1)* %field, i32 5)
  ret i8 addrspace(1)* %ref
}

declare i8 addrspace(1)* @llvm.cj.gcread.ref(
    i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
declare i8 addrspace(1)* @llvm.cj.atomic.load(
    i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, i32)
