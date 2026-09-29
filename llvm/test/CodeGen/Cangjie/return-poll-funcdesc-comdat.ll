; REQUIRES: x86-registered-target
; RUN: llc --cangjie-pipeline -no-stacktrace-info -mtriple=x86_64-unknown-linux-gnu %s -o - | FileCheck %s
; ComdatMethodTable uses the same descriptor emitter as normal/init records.
$member = comdat any
declare void @callee() "gc-leaf-function"
define linkonce_odr void @member() comdat($member) gc "cangjie" {
  call void @callee()
  ret void
}
; CHECK: .section .cjmetadata.methodinfo.member,
; CHECK-LABEL: .Lmethod_desc.member:
; CHECK-NEXT: .{{long|word}} {{.*}}
; CHECK-NEXT: .{{long|word}} {{.*}}
; CHECK-NEXT: .{{long|word}} 0
; CHECK-NEXT: .{{long|word}} 0
; CHECK-NEXT: .{{long|word}} 0
; CHECK-NEXT: .{{long|word}} 0
; CHECK-NEXT: {{\.?Ltmp[0-9]+}}:
; CHECK-NEXT: .{{long|word}} {{.*}}
; CHECK-NEXT: .org .Lmethod_desc.member+28, 0
; CHECK-NEXT: .{{long|word}} 1

; Legacy leaf input is not excluded from the comdat table.
$leaf_member = comdat any
define linkonce_odr void @leaf_member() "leaf-function" comdat($leaf_member) gc "cangjie" {
  ret void
}
; CHECK: .section .cjmetadata.methodinfo.leaf_member,
; CHECK-LABEL: .Lmethod_desc.leaf_member:
; CHECK-NEXT: .{{long|word}} .Lstack_map.leaf_member-.Lmethod_desc.leaf_member
; CHECK: .org .Lmethod_desc.leaf_member+28, 0
; CHECK-NEXT: .{{long|word}} 1

; A call-free gc-leaf comdat needs a real frame header even without a poll.
$gc_leaf_member = comdat any
define linkonce_odr void @gc_leaf_member() "gc-leaf-function" comdat($gc_leaf_member) gc "cangjie" {
  ret void
}
; CHECK: .section .cjmetadata.methodinfo.gc_leaf_member,
; CHECK-LABEL: .Lmethod_desc.gc_leaf_member:
; CHECK-NEXT: .{{long|word}} .Lstack_map.gc_leaf_member-.Lmethod_desc.gc_leaf_member
; CHECK: .org .Lmethod_desc.gc_leaf_member+28, 0
; CHECK-NEXT: .{{long|word}} 0
