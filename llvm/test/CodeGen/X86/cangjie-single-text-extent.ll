; RUN: split-file %s %t
; RUN: llc --cangjie-pipeline -split-machine-functions %t/mixed.ll -o - | FileCheck %s --check-prefix=SPLIT
; RUN: llc --cangjie-pipeline -basic-block-sections=labels %t/cj.ll -o /dev/null
; RUN: not --crash llc --cangjie-pipeline -basic-block-sections=all %t/cj.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=ERROR
; RUN: llc -basic-block-sections=all -unique-basic-block-section-names %t/native.ll -o - | FileCheck %s --check-prefix=NATIVE
;
; Exercise the actual layout producer with the same hot/cold profile in
; managed and native functions. CJ scalar codeSize must cover every block;
; the native positive control must still produce a cold text fragment.
; SPLIT-LABEL: managed:
; SPLIT-NOT: .text.split.managed
; SPLIT-NOT: managed.cold:
; SPLIT: .Lfunc_end0:
; SPLIT-LABEL: native:
; SPLIT: .section{{[ 	]+}}.text.split.native
; SPLIT: native.cold:
; ERROR: Cangjie AOT qualification requires one text extent: managed
; NATIVE: .text.native.native.__part.
;
;--- mixed.ll
 target triple = "x86_64-unknown-linux-gnu"
 declare void @hot()
 declare void @cold()
 define void @managed(i1 %cond) gc "cangjie" !prof !0 {
 entry:
   br i1 %cond, label %hot, label %cold, !prof !1
 hot:
   call void @hot()
   ret void
 cold:
   call void @cold()
   ret void
 }
 define void @native(i1 %cond) !prof !0 {
 entry:
   br i1 %cond, label %hot, label %cold, !prof !1
 hot:
   call void @hot()
   ret void
 cold:
   call void @cold()
   ret void
 }
 !0 = !{!"function_entry_count", i64 10000}
 !1 = !{!"branch_weights", i32 10000, i32 0}

;--- cj.ll
 target triple = "x86_64-unknown-linux-gnu"
 define void @managed(i1 %cond) gc "cangjie" {
 entry:
   br i1 %cond, label %a, label %b
 a:
   call void @callee()
   ret void
 b:
   ret void
 }
 declare void @callee()

;--- native.ll
 target triple = "x86_64-unknown-linux-gnu"
 define void @native(i1 %cond) {
 entry:
   br i1 %cond, label %a, label %b
 a:
   call void @callee()
   ret void
 b:
   ret void
 }
 declare void @callee()
