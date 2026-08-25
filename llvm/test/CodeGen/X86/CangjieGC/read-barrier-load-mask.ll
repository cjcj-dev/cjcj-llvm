; The runtime republishes g_cjLoadBadMask at every phase boundary, so the
; provider is mandatory: the declaration must stay strong and the load
; unconditional. A weak/optional provider would let a build link against a
; runtime that never flips the good colour, and fail silently instead of at
; load time. Guard both the IR shape and the ELF binding.

; RUN: llc --cangjie-pipeline -mtriple=x86_64 \
; RUN:   -print-module-scope -print-after=cj-barrier-lowering \
; RUN:   -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 \
; RUN:   -filetype=obj -o - < %s | llvm-readelf --symbols - \
; RUN:   | FileCheck %s --check-prefix=ELF

; CHECK: @g_cjLoadBadMask = external global i64
; CHECK-LABEL: define i8 addrspace(1)* @read_ref(
; CHECK: [[MASK:%.*]] = load i64, i64* @g_cjLoadBadMask
; CHECK-NOT: cj.loadbadmask.ispresent
; CHECK: [[BAD:%.*]] = and i64 {{%.*}}, [[MASK]]

; The store side is colour-tested and painted unconditionally too.
; CHECK-LABEL: define void @write_ref(
; CHECK: load i64, i64* @g_cjStoreBadMask
; CHECK: load i64, i64* @g_cjStoreGoodMask

; ELF-NOT: WEAK {{.*}} g_cjLoadBadMask
; ELF: NOTYPE GLOBAL DEFAULT UND g_cjLoadBadMask

define i8 addrspace(1)* @read_ref(i8 addrspace(1)* %obj,
                                  i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
entry:
  %ref = call i8 addrspace(1)* @llvm.cj.gcread.ref(
      i8 addrspace(1)* %obj, i8 addrspace(1)* addrspace(1)* %field)
  ret i8 addrspace(1)* %ref
}

define void @write_ref(i8 addrspace(1)* %value, i8 addrspace(1)* %obj,
                       i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
entry:
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value,
      i8 addrspace(1)* %obj, i8 addrspace(1)* addrspace(1)* %field)
  ret void
}

declare i8 addrspace(1)* @llvm.cj.gcread.ref(
    i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
declare void @llvm.cj.gcwrite.ref(
    i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
