# RUN: split-file %s %t
# RUN: not llvm-mc -triple=x86_64-linux -filetype=obj %t/no-entry.s -o /dev/null 2>&1 | FileCheck %s --check-prefix=ENTRY
# RUN: not llvm-mc -triple=x86_64-linux -filetype=obj %t/duplicate.s -o /dev/null 2>&1 | FileCheck %s --check-prefix=DUP
# RUN: not llvm-mc -triple=x86_64-linux -filetype=obj %t/extent.s -o /dev/null 2>&1 | FileCheck %s --check-prefix=EXTENT
# ENTRY: Cangjie AOT qualification for entry: missing entry state
# DUP: Cangjie AOT qualification for entry: duplicate saved site
# EXTENT: Cangjie AOT qualification for entry: function does not have one text extent
#--- no-entry.s
.text
entry:
.byte 0x90
later:
.byte 0x90
end:
.section .cjmetadata.stackmap,"aw",@progbits
.cj_aot_qualification entry, end, 1, 0, later, 3
#--- duplicate.s
.text
entry:
.byte 0x90
end:
.section .cjmetadata.stackmap,"aw",@progbits
.cj_aot_qualification entry, end, 1, 2, entry, 0, end, 1, 3, end, 1, 3
#--- extent.s
.text
entry:
.byte 0x90
.section .text.cold,"ax",@progbits
end:
.section .cjmetadata.stackmap,"aw",@progbits
.cj_aot_qualification entry, end, 1, 0, entry, 0
