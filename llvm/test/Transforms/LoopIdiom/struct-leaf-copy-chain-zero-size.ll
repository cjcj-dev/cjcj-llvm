; RUN: opt -aa-pipeline=basic-aa -passes=loop-idiom -disable-loop-idiom-memset -S < %s | FileCheck %s
; RUN: opt -aa-pipeline=basic-aa -passes='loop-mssa(loop-idiom)' -disable-loop-idiom-memset -verify-memoryssa -S < %s | FileCheck %s

; A zero-sized leaf must not join a field-wise copy chain. With memset idioms
; disabled, two zero-sized stores of one load sit at the offset of the first
; i64 leaf; admitting them listed that load twice in the chain and erased it
; twice. Only the two i64 leaves form the 16-byte element copy; the zero-sized
; accesses stay in the loop.

target triple = "x86_64-unknown-linux-gnu"

define void @zero_duplicate(i8* noalias %d, i8* noalias %s) {
; CHECK-LABEL: @zero_duplicate(
; CHECK:       call void @llvm.memcpy.p0i8.p0i8.i64(i8* align 8 %d, i8* align 8 %s, i64 32, i1 false)
; CHECK:       loop:
; CHECK:         %z = load [0 x i8], [0 x i8]* %sz, align 1
; CHECK-NEXT:    store [0 x i8] %z, [0 x i8]* %dz, align 1
; CHECK-NEXT:    store [0 x i8] %z, [0 x i8]* %dz, align 1
; CHECK-NOT:     load i64
; CHECK-NOT:     store i64
; CHECK:         ret void
entry:
  br label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %next, %loop ]
  %off = shl nuw nsw i64 %i, 4
  %sp = getelementptr inbounds i8, i8* %s, i64 %off
  %dp = getelementptr inbounds i8, i8* %d, i64 %off
  %sz = bitcast i8* %sp to [0 x i8]*
  %dz = bitcast i8* %dp to [0 x i8]*
  %z = load [0 x i8], [0 x i8]* %sz, align 1
  store [0 x i8] %z, [0 x i8]* %dz, align 1
  store [0 x i8] %z, [0 x i8]* %dz, align 1
  %sx = bitcast i8* %sp to i64*
  %dx = bitcast i8* %dp to i64*
  %sp8 = getelementptr inbounds i8, i8* %sp, i64 8
  %dp8 = getelementptr inbounds i8, i8* %dp, i64 8
  %sy = bitcast i8* %sp8 to i64*
  %dy = bitcast i8* %dp8 to i64*
  %x = load i64, i64* %sx, align 8
  %y = load i64, i64* %sy, align 8
  store i64 %x, i64* %dx, align 8
  store i64 %y, i64* %dy, align 8
  %next = add nuw nsw i64 %i, 1
  %done = icmp eq i64 %next, 2
  br i1 %done, label %exit, label %loop
exit:
  ret void
}
