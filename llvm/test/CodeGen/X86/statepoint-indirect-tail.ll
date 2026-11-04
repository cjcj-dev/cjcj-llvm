; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu -mattr=+retpoline-indirect-calls %S/../Inputs/statepoint-indirect-tail.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=THUNK
; THUNK: LLVM ERROR: Lowering register statepoints with thunks not yet implemented.
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs -stop-after=finalize-isel %S/../Inputs/statepoint-indirect-tail.ll -o - | FileCheck %s --check-prefix=ISEL
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs %S/../Inputs/statepoint-indirect-tail.ll -o - | FileCheck %s --check-prefix=ASM
; RUN: llc -mtriple=x86_64-pc-windows-msvc -verify-machineinstrs -stop-after=finalize-isel %S/../Inputs/statepoint-indirect-tail.ll -o - | FileCheck %s --check-prefix=WIN
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs -stop-after=finalize-isel %S/Inputs/statepoint-tail-win64cc.ll -o - | FileCheck %s --check-prefix=WINCC
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs -stop-after=finalize-isel %S/Inputs/statepoint-tail-transition.ll -o - | FileCheck %s --check-prefix=TRANSITION
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -cangjie-pipeline -verify-machineinstrs %S/../Inputs/statepoint-indirect-tail-cj.ll -o - | FileCheck %s --check-prefix=ASM
;
; The callee and six integer arguments span a call. Only the target is
; constrained; RA must arrange a reload/copy that survives the epilogue.
; ISEL-LABEL: name:            indirect_pressure
; ISEL: %0:gr64_tc = COPY $rdi
; ISEL: CALL64pcrel32 {{.*}}@clobber
; ISEL: STATEPOINT_TAIL_CALL 123, 0, 6, %0,
; ISEL-LABEL: name:            direct_control
; ISEL: STATEPOINT_TAIL_CALL 123, 0, 0, {{.*}}@direct_callee,
; ISEL-LABEL: name:            patch_fallback
; ISEL: STATEPOINT 123, 16,
; ISEL-LABEL: name:            nonvoid_fallback
; ISEL: STATEPOINT 123, 0,
; ISEL-LABEL: name:            relocate_fallback
; ISEL: STATEPOINT 123, 0,
; ISEL-LABEL: name:            stack_fallback
; ISEL: STATEPOINT 123, 0,
; ISEL-LABEL: name:            cj2c_fallback
; ISEL: STATEPOINT 123, 0, 0, {{.*}}@cj2c_callee,
; ISEL-LABEL: name:            c2cj_fallback
; ISEL: STATEPOINT 123, 0, 0, {{.*}}@c2cj_callee,
; ISEL-LABEL: name:            not_tail
; ISEL: STATEPOINT 123, 0,
; ISEL-LABEL: name:            disabled_fallback
; ISEL: STATEPOINT 123, 0,
;
; ASM-LABEL: indirect_pressure:
; ASM: callq clobber
; ASM: popq %rbx
; ASM: popq %r12
; ASM: popq %r13
; ASM: popq %r14
; ASM: popq %rbp
; ASM: jmpq *%{{(rax|rcx|rdx|rsi|rdi|r8|r9|r11)}}
; ASM-LABEL: direct_control:
; ASM: jmp direct_callee
;
; Even a zero-argument Win64 statepoint retains the shadow-space fallback.
; WIN-LABEL: name:            indirect_zero
; WIN: STATEPOINT 123, 0, 0,
; WIN-NOT: STATEPOINT_TAIL_CALL
; WIN-LABEL: name:            direct_control
; WIN: STATEPOINT 123, 0, 0,
; WINCC-LABEL: name:            win64cc_zero
; WINCC: STATEPOINT 123, 0, 0,
; WINCC-NOT: STATEPOINT_TAIL_CALL
; TRANSITION-LABEL: name:            transition_fallback
; TRANSITION: STATEPOINT 123, 0,
; TRANSITION-NOT: STATEPOINT_TAIL_CALL
