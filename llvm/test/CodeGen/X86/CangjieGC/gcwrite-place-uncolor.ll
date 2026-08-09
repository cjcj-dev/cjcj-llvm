; RUN: llc --cangjie-pipeline -mtriple=x86_64 -print-after=cj-barrier-lowering \
; RUN:   -o /dev/null < %s 2>&1 | FileCheck %s

; Idle/phase<=8 fastpath of cj.gcwrite.ref must strip colour from the place
; before the bare store (refplace / G-A2 place peel).

define void @write_ref_place(i8 addrspace(1)* %val, i8 addrspace(1)* %base,
                             i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
; CHECK-LABEL: define void @write_ref_place(
; CHECK: gcNoRunning:
; CHECK: [[PLACE_INT:%.*]] = ptrtoint i8 addrspace(1)* addrspace(1)* %field to i64
; CHECK-NEXT: [[PLACE_ADDR:%.*]] = and i64 [[PLACE_INT]], 281474976710655
; CHECK-NEXT: [[PLACE_PLAIN:%.*]] = inttoptr i64 [[PLACE_ADDR]] to i8 addrspace(1)* addrspace(1)*
; CHECK: store i8 addrspace(1)* %val, i8 addrspace(1)* addrspace(1)* [[PLACE_PLAIN]]
entry:
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %val, i8 addrspace(1)* %base,
                                 i8 addrspace(1)* addrspace(1)* %field)
  ret void
}

define void @write_struct_place(i8 addrspace(1)* %base, i8 addrspace(1)* %dst,
                                i8 addrspace(1)* %src, i64 %sz) gc "cangjie" {
; CHECK-LABEL: define void @write_struct_place(
; CHECK: gcNoRunning:
; CHECK: [[DST_INT:%.*]] = ptrtoint i8 addrspace(1)* %dst to i64
; CHECK: and i64 [[DST_INT]], 281474976710655
; CHECK: [[SRC_INT:%.*]] = ptrtoint i8 addrspace(1)* %src to i64
; CHECK: and i64 [[SRC_INT]], 281474976710655
; CHECK: call void @llvm.memcpy
entry:
  call void @llvm.cj.gcwrite.struct(i8 addrspace(1)* %base,
                                    i8 addrspace(1)* %dst,
                                    i8 addrspace(1)* %src, i64 %sz)
  ret void
}

define void @atomic_store_place(i8 addrspace(1)* %ref, i8 addrspace(1)* %obj,
                                i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
; CHECK-LABEL: define void @atomic_store_place(
; CHECK: gcNoRunning:
; CHECK: [[F_INT:%.*]] = ptrtoint i8 addrspace(1)* addrspace(1)* %field to i64
; CHECK: and i64 [[F_INT]], 281474976710655
; CHECK: store atomic
entry:
  call void @llvm.cj.atomic.store(i8 addrspace(1)* %ref, i8 addrspace(1)* %obj,
                                  i8 addrspace(1)* addrspace(1)* %field, i32 5)
  ret void
}

declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*,
                                  i8 addrspace(1)* addrspace(1)*)
declare void @llvm.cj.gcwrite.struct(i8 addrspace(1)*, i8 addrspace(1)*,
                                     i8 addrspace(1)*, i64)
declare void @llvm.cj.atomic.store(i8 addrspace(1)*, i8 addrspace(1)*,
                                   i8 addrspace(1)* addrspace(1)*, i32)
