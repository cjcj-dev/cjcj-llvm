; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O0 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; Multiple marked accesses share the pass worklist. Removing a lowered load
; must not leave a stale entry for the following write-barrier sweep.
; ZGC z_x86_64.ad:61-99: retain color/store/load/uncolor as one data path.
define i8 addrspace(1)* @roundtrip(i8 addrspace(1)* %value,
    i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot) gc "cangjie" {
; CHECK-LABEL: define i8 addrspace(1)* @roundtrip(
; CHECK: %cj.store.new.bits = call i64 asm
; CHECK: %cj.store.colored = or i64
; CHECK: store volatile i64 %cj.store.colored
; CHECK-NEXT: [[LOADED:%.*]] = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %slot, {{.*}}!cj.colored.value
; CHECK-NEXT: [[BITS:%.*]] = ptrtoint i8 addrspace(1)* [[LOADED]] to i64
; CHECK-NEXT: %cj.load.shift = load i64, i64* @g_cjLoadShift
; CHECK-NEXT: %cj.load.address = lshr i64 [[BITS]], %cj.load.shift
; CHECK-NEXT: [[PTR:%.*]] = inttoptr i64 %cj.load.address to i8 addrspace(1)*
; CHECK-NEXT: ret i8 addrspace(1)* [[PTR]]
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot, i32 1), !cj.barrier.elided !0
  %result = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %base, i8 addrspace(1)* addrspace(1)* %slot), !cj.barrier.elided !0
  ret i8 addrspace(1)* %result
}

declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)
declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
!0 = !{}
