# RUN: llvm-mc -triple=x86_64-unknown-linux-gnu -filetype=obj %s -o %t
# RUN: llvm-readobj --hex-dump=.cjmetadata.stackmap %t | FileCheck %s
# RUN: llvm-mc -triple=x86_64-unknown-linux-gnu -filetype=asm %s -o %t.s
# RUN: llvm-mc -triple=x86_64-unknown-linux-gnu -filetype=obj %t.s -o %t.roundtrip
# RUN: llvm-readobj --hex-dump=.cjmetadata.stackmap %t.roundtrip | FileCheck %s
# Final offsets, not source event counts, determine the four transitions.
# The second alignment has zero length and must not add an invalid interval.
# CHECK: 0x00000000 434a5131 40000000 04000000 02000000
# CHECK: 0x00000010 00000000 00000000 01000000 01000000
# CHECK: 0x00000020 02000000 00000000 04000000 03000000
# CHECK: 0x00000030 04000000 02000300 05000000 01000300
.text
entry:
.byte 0x90
slot:
.byte 0x90
padding:
.p2align 2
ready:
zero_padding:
.p2align 2
zero_end:
.byte 0x90
end:
.section .cjmetadata.stackmap,"a",@progbits
.p2align 2
.cj_aot_qualification entry, end, 6, 2, entry, 0, slot, 1, padding, 0, ready, 3, zero_padding, 0, zero_end, 3, end, 1, 3, ready, 2, 3
