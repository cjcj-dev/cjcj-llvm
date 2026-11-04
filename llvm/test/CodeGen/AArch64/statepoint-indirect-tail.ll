; RUN: llc -mtriple=aarch64-unknown-linux-gnu -mattr=+bti -verify-machineinstrs -stop-after=finalize-isel %S/../Inputs/statepoint-indirect-tail.ll -o - | FileCheck %s --check-prefix=ISEL
; RUN: llc -mtriple=aarch64-unknown-linux-gnu -mattr=+bti -verify-machineinstrs %S/../Inputs/statepoint-indirect-tail.ll -o - | FileCheck %s --check-prefix=ASM
; RUN: llc -mtriple=aarch64-unknown-linux-gnu -mattr=+bti -cangjie-pipeline -verify-machineinstrs %S/../Inputs/statepoint-indirect-tail-cj.ll -o - | FileCheck %s --check-prefix=ASM
;
; The target restrictions must be applied before RA, including under BTI.
; ISEL-LABEL: name:            indirect_pressure
; ISEL: %0:tcgpr64 = COPY $x0
; ISEL: BL @clobber
; ISEL: STATEPOINT_TAIL_CALL 123, 0, 6, %0,
; ISEL-SAME: implicit-def dead early-clobber $lr
; ISEL-LABEL: name:            indirect_bti
; ISEL: %0:rtcgpr64 = COPY $x0
; ISEL: STATEPOINT_TAIL_CALL 123, 0, 6, %0,
; ISEL-SAME: implicit-def dead early-clobber $lr
; ISEL-LABEL: name:            direct_control
; ISEL: STATEPOINT_TAIL_CALL 123, 0, 0, @direct_callee,
; ISEL-LABEL: name:            patch_fallback
; ISEL: STATEPOINT 123, 16,
; ISEL-LABEL: name:            nonvoid_fallback
; ISEL: STATEPOINT 123, 0,
; ISEL-LABEL: name:            relocate_fallback
; ISEL: STATEPOINT 123, 0,
; ISEL-LABEL: name:            stack_fallback
; ISEL: STATEPOINT 123, 0,
; ISEL-LABEL: name:            cj2c_fallback
; ISEL: STATEPOINT 123, 0, 0, @cj2c_callee,
; ISEL-LABEL: name:            c2cj_fallback
; ISEL: STATEPOINT 123, 0, 0, @c2cj_callee,
; ISEL-LABEL: name:            not_tail
; ISEL: STATEPOINT 123, 0,
; ISEL-LABEL: name:            disabled_fallback
; ISEL: STATEPOINT 123, 0,
;
; ASM-LABEL: indirect_pressure:
; ASM: bl clobber
; ASM: ldp x20, x19,
; ASM: {{(ldr x30,|ldp x29, x30,)}}
; ASM: br x{{([0-9]|1[0-8])}}
; ASM-LABEL: indirect_bti:
; ASM: bti c
; ASM: bl clobber
; ASM: ldp x20, x19,
; ASM: {{(ldr x30,|ldp x29, x30,)}}
; ASM: br x{{(16|17)}}
; ASM-LABEL: direct_control:
; ASM: b direct_callee
