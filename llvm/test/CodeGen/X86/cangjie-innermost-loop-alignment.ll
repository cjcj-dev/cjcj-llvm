; RUN: llc < %s -mtriple=x86_64-unknown-linux-gnu | FileCheck %s --check-prefixes=DEFAULT,NATIVE
; RUN: llc < %s -mtriple=x86_64-unknown-linux-gnu -align-loops=16 | FileCheck %s --check-prefixes=OVERRIDE,NATIVE
; RUN: llc < %s -mtriple=x86_64-unknown-linux-gnu -x86-experimental-pref-innermost-loop-alignment=4 | FileCheck %s --check-prefixes=OVERRIDE,NATIVE
; RUN: llc < %s -mtriple=x86_64-unknown-linux-musl | FileCheck %s --check-prefixes=OVERRIDE,NATIVE
;
; The native control and managed outer loop retain 16-byte alignment. The
; managed innermost loop gets 32 bytes only on GNU/Linux x86-64 and without an
; explicit override. This changes placement, not loop operations or GC polls.

declare void @opaque()

; DEFAULT-LABEL: managed_nested:
; DEFAULT: .p2align 4, 0x90
; DEFAULT-NEXT: .LBB{{[0-9]+}}_1:
; DEFAULT: .p2align 5, 0x90
; DEFAULT-NEXT: .LBB{{[0-9]+}}_2:
; DEFAULT: callq opaque
; DEFAULT: jne
; OVERRIDE-LABEL: managed_nested:
; OVERRIDE: .p2align 4, 0x90
; OVERRIDE-NEXT: .LBB{{[0-9]+}}_1:
; OVERRIDE: .p2align 4, 0x90
; OVERRIDE-NEXT: .LBB{{[0-9]+}}_2:
; OVERRIDE: callq opaque
; OVERRIDE: jne
define void @managed_nested(i32 %n, i32 %m) gc "cangjie" {
entry:
  br label %outer
outer:
  %i = phi i32 [ 0, %entry ], [ %inext, %outer_latch ]
  br label %inner
inner:
  %j = phi i32 [ 0, %outer ], [ %jnext, %inner ]
  call void @opaque()
  %jnext = add i32 %j, 1
  %jcond = icmp ne i32 %jnext, %m
  br i1 %jcond, label %inner, label %outer_latch
outer_latch:
  %inext = add i32 %i, 1
  %icond = icmp ne i32 %inext, %n
  br i1 %icond, label %outer, label %exit
exit:
  ret void
}

; NATIVE-LABEL: native_nested:
; NATIVE: .p2align 4, 0x90
; NATIVE-NEXT: .LBB{{[0-9]+}}_1:
; NATIVE: .p2align 4, 0x90
; NATIVE-NEXT: .LBB{{[0-9]+}}_2:
; NATIVE: callq opaque
; NATIVE: jne
define void @native_nested(i32 %n, i32 %m) {
entry:
  br label %outer
outer:
  %i = phi i32 [ 0, %entry ], [ %inext, %outer_latch ]
  br label %inner
inner:
  %j = phi i32 [ 0, %outer ], [ %jnext, %inner ]
  call void @opaque()
  %jnext = add i32 %j, 1
  %jcond = icmp ne i32 %jnext, %m
  br i1 %jcond, label %inner, label %outer_latch
outer_latch:
  %inext = add i32 %i, 1
  %icond = icmp ne i32 %inext, %n
  br i1 %icond, label %outer, label %exit
exit:
  ret void
}
