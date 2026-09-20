; RUN: llc --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu -debug-only=branch-relaxation -o /dev/null < %S/tlab-inline.ll 2>&1 | FileCheck %s
; REQUIRES: aarch64-registered-target, asserts
;
; The branch relaxation pass calls AArch64InstrInfo's real size estimator.
; The array block comprises 32 bytes of frame/call bookkeeping plus the
; twelve emitted TLAB instructions (48 bytes). Keeping the old 52 estimate
; makes this block 0x54 and fails here, independently of assembly text checks.
; CHECK: Basic blocks before relaxation
; CHECK-NEXT: %bb.0 offset=00000000 size=0x10
; CHECK: Basic blocks before relaxation
; CHECK-NEXT: %bb.0 offset=00000000 size=0x50
