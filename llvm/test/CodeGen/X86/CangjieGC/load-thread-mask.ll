; RUN: llc --cangjie-pipeline -mtriple=x86_64 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; ZGC zBarrierSetAssembler_x86.cpp:274-331: non-nmethod mask test.
define i8 addrspace(1)* @read(i8 addrspace(1)* %base,
                             i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
; CHECK-LABEL: define i8 addrspace(1)* @read(
; CHECK: call i8* asm sideeffect "movq %r15, $0"
; CHECK: load i64, i64* @g_cjThreadGCDataOffset
; CHECK: load i64, i64* @g_cjLoadBadMaskOffset
; CHECK: %cj.loadbadmask = load i64
; CHECK: and i64 {{.*}}, %cj.loadbadmask
; CHECK: gcMarked:
; CHECK: call i8 addrspace(1)* @CJ_MCC_ReadRefField
  %value = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot)
  ret i8 addrspace(1)* %value
}
declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
