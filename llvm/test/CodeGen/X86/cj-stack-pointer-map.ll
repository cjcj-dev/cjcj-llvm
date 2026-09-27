; RUN: llc -O0 --cangjie-pipeline -cj-stack-grow=false -mtriple=x86_64-unknown-linux-gnu -filetype=obj < %s -o %t.off.o
; RUN: %python %S/Inputs/check-cj-stack-pointer-map.py %t.off.o
; RUN: llc -O0 --cangjie-pipeline -cj-stack-grow=true -mtriple=x86_64-unknown-linux-gnu -filetype=obj < %s -o %t.on.o
; RUN: %python %S/Inputs/check-cj-stack-pointer-map.py %t.on.o
; RUN: llc -O0 --cangjie-pipeline -cj-stack-grow=false -mtriple=x86_64-unknown-linux-gnu < %s | FileCheck %s
; RUN: llc -O0 --cangjie-pipeline -cj-stack-grow=true -mtriple=x86_64-unknown-linux-gnu < %s | FileCheck %s
; RUN: llc -O2 --cangjie-pipeline -cj-stack-grow=false -mtriple=x86_64-unknown-linux-gnu < %s | FileCheck %s
; RUN: llc -O2 --cangjie-pipeline -cj-stack-grow=true -mtriple=x86_64-unknown-linux-gnu < %s | FileCheck %s
;
; The incoming sret address names a caller frame. It is live across the call
; and must be described at the return PC even when stack growth is disabled.
; Check the decoded product map, including an empty-map control in the same IR.

%record = type { i64, i64 }
declare void @fill(%record* sret(%record))
declare void @poll()
declare token @llvm.cj.gc.statepoint(...)

define void @sret_forward(%record* sret(%record) %out) gc "cangjie" {
entry:
  %t = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, void (%record*)* @fill, i32 1, i32 0, %record* %out)
  %field = getelementptr %record, %record* %out, i32 0, i32 1
  store volatile i64 7, i64* %field
  ret void
}

define void @no_stack_pointer() gc "cangjie" {
entry:
  %t = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, void ()* @poll, i32 0, i32 0)
  ret void
}

; CHECK-LABEL: .Lstack_map.sret_forward:
; CHECK: #StackMapItem nums:2
; CHECK: .long {{.*}}-sret_forward
; CHECK: #{{\[}}RegIdx: -1, SlotIdx: -1, LNIdx: -1, DerivedStartIdx: -1, SPRegIdx: {{-1|[0-9]+}}, SPSlotIdx: {{[0-9]+}}]
; CHECK: #{{(RegNums|SlotsNums)}}: 1
; CHECK-LABEL: .Lstack_map.no_stack_pointer:
; CHECK: #StackMapItem nums:2
; CHECK: .long {{.*}}-no_stack_pointer
; CHECK: #[RegIdx: -1, SlotIdx: -1, LNIdx: -1, DerivedStartIdx: -1, SPRegIdx: -1, SPSlotIdx: -1]
