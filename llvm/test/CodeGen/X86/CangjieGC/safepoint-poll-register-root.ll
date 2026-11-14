; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu -O2 --cj-safepoint-outline=false \
; RUN:   -stop-after=fixup-statepoint-caller-saved < %s | FileCheck %s --check-prefix=REG
; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu -O2 --cj-safepoint-outline=false \
; RUN:   -cj-safepoint-poll-max-registers-for-gc-values=0 \
; RUN:   -stop-after=fixup-statepoint-caller-saved < %s | FileCheck %s --check-prefix=SLOT
; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu -O2 \
; RUN:   -stop-after=fixup-statepoint-caller-saved < %s | FileCheck %s --check-prefix=OUTLINE
;
; An inline poll (statepoint ID 3, --cj-safepoint-outline=false) reaches
; CJ_MCC_HandleSafepoint only on its slow path. That stub saves every GPR into the
; save area the runtime maps for the poll's immediate managed sender
; (StackInfo.cpp UpdateRegisterMap, FrameType::SAFEPOINT), so the root live
; across the poll stays in a register (tied def) instead of a frame slot. The
; ordinary call statepoint (ID 0) still passes its root in a frame slot
; (frame_x86.inline.hpp:455-464). An outlined poll (default) becomes a
; SafepointStub statepoint (ID 4) and also keeps its frame slot.

; REG-LABEL: name: poll_root
; REG: renamable $[[R:[a-z0-9]+]] = STATEPOINT 3, 0, 0, {{.*}}@CJ_MCC_HandleSafepoint, 2, {{[0-9]+}}, 2, 0, 2, 0, 2, 1, killed renamable $[[R]](tied-def 0), 2, 0, 2, 1, 0, 0
; REG-NOT: STATEPOINT 3, {{.*}}%stack.
; REG: STATEPOINT 0, 0, 0, {{.*}}@callee, 2, {{[0-9]+}}, 2, 0, 2, 0, 2, 1, 1, 8, %stack.{{[0-9]+}}, 0,
; SLOT-LABEL: name: poll_root
; SLOT: STATEPOINT 3, 0, 0, {{.*}}@CJ_MCC_HandleSafepoint, 2, {{[0-9]+}}, 2, 0, 2, 0, 2, 1, 1, 8, %stack.{{[0-9]+}}, 0,
; SLOT: STATEPOINT 0, 0, 0, {{.*}}@callee, 2, {{[0-9]+}}, 2, 0, 2, 0, 2, 1, 1, 8, %stack.{{[0-9]+}}, 0,
; OUTLINE-LABEL: name: poll_root
; OUTLINE: STATEPOINT 4, 0, 0, @CJ_Safepoint_Stub, 2, {{[0-9]+}}, 2, 0, 2, 0, 2, 1, 1, 8, %stack.{{[0-9]+}}, 0,
; OUTLINE: STATEPOINT 0, 0, 0, {{.*}}@callee, 2, {{[0-9]+}}, 2, 0, 2, 0, 2, 1, 1, 8, %stack.{{[0-9]+}}, 0,

target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"

define void @poll_root(i8 addrspace(1)* %root, i64 %n) gc "cangjie" {
entry:
  br label %loop

loop:
  %p = phi i8 addrspace(1)* [ %root, %entry ], [ %reloc, %loop ]
  %i = phi i64 [ 0, %entry ], [ %inc, %loop ]
  %gep = getelementptr i8, i8 addrspace(1)* %p, i64 %i
  store i8 1, i8 addrspace(1)* %gep, align 1
  %inc = add nuw nsw i64 %i, 1
  %tok = call cangjiegccc token (...) @llvm.cj.gc.statepoint(i64 3, i32 0, void ()* @CJ_MCC_HandleSafepoint, i32 0, i32 0) [ "gc-live"(i8 addrspace(1)* %p) ]
  %reloc = call coldcc i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token %tok, i32 0, i32 0)
  %cmp = icmp slt i64 %inc, %n
  br i1 %cmp, label %loop, label %exit

exit:
  %tok2 = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, void ()* @callee, i32 0, i32 0) [ "gc-live"(i8 addrspace(1)* %reloc) ]
  %reloc2 = call coldcc i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token %tok2, i32 0, i32 0)
  store i8 2, i8 addrspace(1)* %reloc2, align 1
  ret void
}

declare token @llvm.cj.gc.statepoint(...)
declare i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token, i32, i32)
declare void @CJ_MCC_HandleSafepoint()
declare void @callee()
