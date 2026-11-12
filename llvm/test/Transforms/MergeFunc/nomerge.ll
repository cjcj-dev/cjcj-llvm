; RUN: opt -passes=mergefunc -S < %s | FileCheck %s --check-prefix=MERGED
; RUN: opt -passes=mergefunc -S < %s | FileCheck %s --check-prefix=KEPT

; A function carrying nomerge keeps its own body even when it is identical
; to other functions; the two plain twins are still folded.

define i32 @plain(i32 %x) {
  %y = add i32 %x, 7
  %z = mul i32 %y, 3
  ret i32 %z
}

define i32 @kept(i32 %x) nomerge {
  %y = add i32 %x, 7
  %z = mul i32 %y, 3
  ret i32 %z
}

define i32 @twin(i32 %x) {
  %y = add i32 %x, 7
  %z = mul i32 %y, 3
  ret i32 %z
}

; MERGED: tail call i32 @{{plain|twin}}(

; KEPT-LABEL: define i32 @kept(
; KEPT-NEXT:    %y = add i32 %x, 7
; KEPT-NEXT:    %z = mul i32 %y, 3
; KEPT-NEXT:    ret i32 %z
