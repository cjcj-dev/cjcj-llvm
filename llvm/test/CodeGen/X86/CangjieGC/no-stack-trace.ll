; RUN: llc --cangjie-pipeline -mtriple=x86_64 -no-stacktrace-info  < %s | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -stack-trace-format=simple  < %s

; CHECK: .Lmethod_desc.cj_entry$:
; CHECK-NEXT:  .long   .Lstack_map.cj_entry$-.Lmethod_desc.cj_entry$
; CHECK-NEXT:  .long   .Lfunc_end0-.Lfunc_begin0
; CHECK-NEXT:  .long   0
; CHECK-NEXT:  .long   0
; CHECK-NEXT:  .long   0
; CHECK-NEXT:  .long   0

define i32 @"cj_entry$"() #11 gc "cangjie" {
entry:
  ret i32 2
}
