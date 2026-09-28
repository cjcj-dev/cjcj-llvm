; REQUIRES: x86-registered-target
; RUN: llc --cangjie-pipeline -no-stacktrace-info -mtriple=x86_64-unknown-linux-gnu %s -o - | FileCheck %s
; ComdatMethodTable uses the same descriptor emitter as normal/init records.
$member = comdat any
declare void @callee() "gc-leaf-function"
define linkonce_odr void @member() gc "cangjie" comdat($member) {
  call void @callee()
  ret void
}
; CHECK: .section .cjmetadata.methodinfo.member,
; CHECK-LABEL: .Lmethod_desc.member:
; CHECK-NEXT: .long {{.*}}
; CHECK-NEXT: .long {{.*}}
; CHECK-NEXT: .long 0
; CHECK-NEXT: .long 0
; CHECK-NEXT: .long 0
; CHECK-NEXT: .long 0
; CHECK-NEXT: {{\.?Ltmp[0-9]+}}:
; CHECK-NEXT: .long {{.*}}
; CHECK-NEXT: .long 1
