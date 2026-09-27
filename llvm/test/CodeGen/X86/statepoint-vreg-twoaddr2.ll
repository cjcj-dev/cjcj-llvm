; RUN: llc -O2 --max-registers-for-gc-values=16 --mtriple x86_64-pc-linux-gnu --print-after='twoaddressinstruction' < %s --filetype=obj 2>&1 | FileCheck %s

; This test checks that TwoAddressInstruction pass will create COPY instruction for registers
; with inconsistent types.

declare i1 @return_i1()
declare i32 @consume()

; CHECK-LABEL: test_relocate_norex
; CHECK: [[VREG0:%[0-9]]]:gr64 = COPY killed $rdi
; CHECK: [[VREG1:%[0-9]]]:gr64_norex = COPY killed [[VREG0]]:gr64
; CHECK: [[VREG1]]:gr64_norex = STATEPOINT 0, 0, 0, target-flags(x86-plt) @return_i1, 2, 0, 2, 0, 2, 0, 2, 1, [[VREG1]]:gr64_norex(tied-def 0), 2, 0, 2, 1, 0, 0, <regmask $bh $bl $bp $bph $bpl $bx $ebp $ebx $hbp $hbx $rbp $rbx $r12 $r13 $r14 $r15 $r12b $r13b $r14b $r15b $r12bh $r13bh $r14bh $r15bh $r12d $r13d $r14d $r15d $r12w $r13w $r14w $r15w $r12wh and 3 more...>, implicit-def $rsp, implicit-def $ssp, implicit-def $al
; CHECK: %4:gr8_norex = COPY killed %3.sub_8bit_hi:gr32_abcd
; CHECK: MOV8mr_NOREX killed [[VREG1]]:gr64_norex, 1, $noreg, 53, $noreg, killed %4:gr8_norex :: (store (s8) into %ir.ptr, addrspace 1)

define i1 @test_relocate_norex(i8 addrspace(1)* %a) gc "statepoint-example" {
entry:
%safepoint_token = tail call token (i64, i32, i1 ()*, i32, i32, ...) @llvm.experimental.gc.statepoint.p0f_i1f(i64 0, i32 0, i1 ()* elementtype(i1 ()) @return_i1, i32 0, i32 0, i32 0, i32 0) [ "gc-live"(i8 addrspace(1)* %a) ]
%rel1 = call i8 addrspace(1)* @llvm.experimental.gc.relocate.p1i8(token %safepoint_token, i32 0, i32 0) ; (%a, %a)
%res1 = call zeroext i1 @llvm.experimental.gc.result.i1(token %safepoint_token)
%var1 = call i32 @consume()
%tag1 = lshr i32 %var1, 8
%tag2 = trunc i32 %tag1 to i8
%ptr = getelementptr inbounds i8, i8 addrspace(1)* %rel1, i64 53
store i8 %tag2, i8 addrspace(1)* %ptr, align 1
ret i1 %res1
}

; Function Attrs: nounwind readnone
declare i8 addrspace(1)* @llvm.experimental.gc.relocate.p1i8(token, i32 immarg, i32 immarg) #0

declare token @llvm.experimental.gc.statepoint.p0f_i1f(i64 immarg, i32 immarg, i1 ()*, i32 immarg, i32 immarg, ...)

; Function Attrs: nounwind readnone
declare i1 @llvm.experimental.gc.result.i1(token) #0

attributes #0 = { nounwind readnone }