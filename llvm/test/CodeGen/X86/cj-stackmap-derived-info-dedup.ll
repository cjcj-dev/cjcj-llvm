; Copyright (c) Huawei Technologies Co., Ltd. 2025. All rights reserved.
; This source file is part of the Cangjie project, licensed under Apache-2.0
; with Runtime Library Exception.

; See https://cangjie-lang.cn/pages/LICENSE for license information.

; RUN: llc -O0 --cangjie-pipeline -mtriple x86_64-pc-linux-gnu < %s | FileCheck %s

; Repeated callsites with the same derived/base location sequence should share
; one compressed DerivedInfo entry instead of appending duplicate table rows.

; The two calls share derived info; the return poll adds a distinct PC row
; whose only root is the returned pointer in rax. It adds no derived info.
; CHECK-LABEL: .Lstack_map.dedup:
; CHECK:      #StackMapItem nums:3
; CHECK:      .long .Ltmp{{[0-9]+}}-dedup
; CHECK-NEXT: #[RegIdx: -1, SlotIdx: 0, LNIdx: -1, DerivedStartIdx: 0, SPRegIdx: -1, SPSlotIdx: -1]
; CHECK:      .long .Ltmp{{[0-9]+}}-dedup
; CHECK-NEXT:      #[RegIdx: -1, SlotIdx: 0, LNIdx: -1, DerivedStartIdx: 0, SPRegIdx: -1, SPSlotIdx: -1]
; CHECK:      .long .Lcj_return_pc{{[0-9]+}}-dedup
; CHECK-NEXT: #[RegIdx: 0, SlotIdx: -1, LNIdx: -1, DerivedStartIdx: -1, SPRegIdx: -1, SPSlotIdx: -1]
; CHECK:      #RegNums: 1
; CHECK-NEXT: {{.*}}#Idx[0]: (0x1=1), rax
; CHECK:      #DerivedInfoNums: 1
; CHECK-NEXT: {{.*}}#Idx[0]: RegIdx: -1, SlotIdx: 1

declare cangjiegccc void @g0()
declare token @llvm.cj.gc.statepoint(...)
declare i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token, i32 immarg,
                                                    i32 immarg)

define i8 addrspace(1)* @dedup(i8 addrspace(1)* %base,
                                i8 addrspace(1)* %derived) gc "cangjie" {
entry:
  %t0 = call cangjiegccc token (...) @llvm.cj.gc.statepoint(i64 1, i32 0, void ()* @g0, i32 0, i32 0) [ "gc-live"(i8 addrspace(1)* %base, i8 addrspace(1)* %derived) ]
  %base0 = call coldcc i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token %t0, i32 0, i32 0)
  %derived0 = call coldcc i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token %t0, i32 0, i32 1)
  %t1 = call cangjiegccc token (...) @llvm.cj.gc.statepoint(i64 2, i32 0, void ()* @g0, i32 0, i32 0) [ "gc-live"(i8 addrspace(1)* %base0, i8 addrspace(1)* %derived0) ]
  %derived1 = call coldcc i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token %t1, i32 0, i32 1)
  ret i8 addrspace(1)* %derived1
}