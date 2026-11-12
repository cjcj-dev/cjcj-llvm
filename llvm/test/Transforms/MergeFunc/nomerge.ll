; RUN: opt -passes=mergefunc -S < %s | FileCheck %s --check-prefix=MERGED
; RUN: opt -passes=mergefunc -S < %s | FileCheck %s --check-prefix=KEPT

; Two identical functions that both carry nomerge have equal attributes, so
; only the nomerge eligibility rule keeps them apart. The two plain twins are
; still folded.

define i32 @plain(i32 %x) {
  %y = add i32 %x, 7
  %z = mul i32 %y, 3
  ret i32 %z
}

define i32 @twin(i32 %x) {
  %y = add i32 %x, 7
  %z = mul i32 %y, 3
  ret i32 %z
}

define i32 @kept(i32 %x) nomerge {
  %y = add i32 %x, 5
  %z = mul i32 %y, 9
  ret i32 %z
}

define i32 @kept_twin(i32 %x) nomerge {
  %y = add i32 %x, 5
  %z = mul i32 %y, 9
  ret i32 %z
}

; MERGED: tail call i32 @{{plain|twin}}(

; KEPT-LABEL: define i32 @kept(
; KEPT-NEXT:    %y = add i32 %x, 5
; KEPT-NEXT:    %z = mul i32 %y, 9
; KEPT-NEXT:    ret i32 %z
; KEPT-LABEL: define i32 @kept_twin(
; KEPT-NEXT:    %y = add i32 %x, 5
; KEPT-NEXT:    %z = mul i32 %y, 9
; KEPT-NEXT:    ret i32 %z
