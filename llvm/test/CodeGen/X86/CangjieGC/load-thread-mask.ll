; Heap slow entry: ZGC zBarrierSetAssembler_x86.cpp:305-331 (o,p).
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; ZGC zBarrierSetAssembler_x86.cpp:274-331: non-nmethod mask test.
define i8 addrspace(1)* @read(i8 addrspace(1)* %base,
                             i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
; CHECK-LABEL: define i8 addrspace(1)* @read(
; CHECK: [[RAW:%.*]] = ptrtoint i8 addrspace(1)* {{%.*}} to i64
; CHECK: call i8* asm sideeffect "movq ${1:c}(%r15), $0", "=r,i,~{memory}"(i64 96)
; CHECK: getelementptr i8, i8* %cj.gcdata{{[0-9]*}}, i64 8
; CHECK: %cj.loadbadmask = load i64
; CHECK: and i64 [[RAW]], %cj.loadbadmask
; CHECK: gcMarked:
; CHECK: call i8 addrspace(1)* @CJ_MCC_LoadBarrierOnOopFieldPreloaded
  %value = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot)
  ret i8 addrspace(1)* %value
}
declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
