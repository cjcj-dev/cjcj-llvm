; RUN: opt < %s -passes='function(irce)' --cangjie-pipeline -S | FileCheck %s

; Test that optimizeNUWCompare does not erase a shared icmp that is still
; used by another branch in the same loop. Previously this caused
; "Uses remain when a value is destroyed!" assertion failure (or SIGSEGV
; in release builds).
; https://gitcode.com/Cangjie/cangjie_compiler/issues/1277

; CHECK-LABEL: @test_shared_cond

define void @test_shared_cond(i64 %n, i64 %byteAdd, i64 %outputN, i64* %buf) {
entry:
  %cmp.entry = icmp sgt i64 %n, 0
  br i1 %cmp.entry, label %preheader, label %done

preheader:
  br label %loop

loop:
  %i = phi i64 [ 0, %preheader ], [ %i.next, %latch ]
  %icmpslt = icmp ult i64 %i, %n
  %add = add nuw nsw i64 %i, %byteAdd
  %icmpuge = icmp ult i64 %add, %outputN
  br i1 %icmpslt, label %bb58, label %bb59

bb58:
  br i1 %icmpuge, label %body1, label %throw1

bb59:
  br i1 %icmpuge, label %body2, label %throw2

body1:
  %gep1 = getelementptr i64, i64* %buf, i64 %add
  store i64 1, i64* %gep1, align 8
  br label %latch

body2:
  %gep2 = getelementptr i64, i64* %buf, i64 %i
  store i64 2, i64* %gep2, align 8
  br label %latch

latch:
  %i.next = add nuw nsw i64 %i, 1
  %exit.cmp = icmp ne i64 %i.next, %n
  br i1 %exit.cmp, label %loop, label %done

throw1:
  unreachable

throw2:
  unreachable

done:
  ret void
}

; After the fix, both branches get their own optimized comparison using
; select/sub hoisted to the preheader, and the original shared icmp is
; cleanly removed (no dangling use).
;
; CHECK: preheader:
; CHECK:    sub i64 %outputN, %byteAdd
; CHECK:    select i1 {{.*}}, i64 {{%[0-9]+}}, i64 0
; CHECK:    select i1 {{.*}}, i64 {{%[0-9]+}}, i64 0
;
; CHECK: bb58:
; CHECK:    icmp ult i64 %i, {{%[0-9]+}}
;
; CHECK: bb59:
; CHECK:    icmp ult i64 %i, {{%[0-9]+}}
;
; CHECK-NOT: icmp ult i64 %add, %outputN
