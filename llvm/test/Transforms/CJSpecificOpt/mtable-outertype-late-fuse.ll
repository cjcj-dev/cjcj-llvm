; RUN: opt -passes=cj-specific-opt -verify-each -S %s | FileCheck %s --check-prefixes=POS,NEG
; RUN: opt -enable-new-pm=0 -cj-specific-opt -verify-each -S %s | FileCheck %s --check-prefixes=POS,NEG
; Late pairing is deliberately narrower than the source intrinsic lowering.
declare i8* @CJ_MCC_GetMTable(i8*, i8*) #0
declare i8* @CJ_MCC_GetMethodOuterTI(i8*, i8*, i64) #0
declare void @opaque()
declare i32 @__gxx_personality_v0(...)
attributes #0 = { readnone speculatable willreturn "cj-runtime" "gc-leaf-function" }

; POS-LABEL: define i8* @pair(
; POS: %mtable.outer.ti = alloca i8*
; POS: [[PAIR:%.*]] = call i8* @CJ_MCC_GetMTableAndOuterTI(i8* %ti, i8* %itf, i64 2, i8** %mtable.outer.ti)
; POS-NEXT: %p = bitcast i8* [[PAIR]] to i8**
; POS: %f0 = load i8*, i8** %p
; POS: %f2 = load i8*, i8** %p2
; POS-NEXT: [[OUT:%.*]] = load i8*, i8** %mtable.outer.ti
; POS-NEXT: %v = call i8* %f2(i8* [[OUT]], i8* %f0)
; POS-NOT: call i8* @CJ_MCC_GetMethodOuterTI
; POS: ret i8* %v
define i8* @pair(i8* noundef %ti, i8* noundef %itf) gc "cangjie" {
  %t = call i8* @CJ_MCC_GetMTable(i8* %ti, i8* %itf)
  %p = bitcast i8* %t to i8**
  %f0 = load i8*, i8** %p, !invariant.load !0
  %p2 = getelementptr i8*, i8** %p, i64 2
  %f2 = load i8*, i8** %p2, !FuncTable !1
  %o = call i8* @CJ_MCC_GetMethodOuterTI(i8* %ti, i8* %itf, i64 2)
  %v = call i8* %f2(i8* %o, i8* %f0)
  ret i8* %v
}

; Only one outer query is paired; the other remains a normal runtime call.
; POS-LABEL: define i8* @one_pair(
; POS: call i8* @CJ_MCC_GetMTableAndOuterTI(i8* %ti, i8* %itf, i64 0,
; POS: call i8* @CJ_MCC_GetMethodOuterTI(i8* %ti, i8* %itf, i64 1)
define i8* @one_pair(i8* noundef %ti, i8* noundef %itf) gc "cangjie" {
  %t = call i8* @CJ_MCC_GetMTable(i8* %ti, i8* %itf)
  %o = call i8* @CJ_MCC_GetMethodOuterTI(i8* %ti, i8* %itf, i64 0)
  %o1 = call i8* @CJ_MCC_GetMethodOuterTI(i8* %ti, i8* %itf, i64 1)
  ret i8* %o1
}

; A preexisting fused consumer remains independent.
; NEG-LABEL: define i8* @already_fused(
; NEG: call i8* @CJ_MCC_GetMTableAndOuterTI(i8* %ti, i8* %itf, i64 0, i8** %slot)
; NEG: load i8*, i8** %slot
declare i8* @CJ_MCC_GetMTableAndOuterTI(i8*, i8*, i64, i8**) #1
attributes #1 = { "cj-runtime" "gc-leaf-function" }
define i8* @already_fused(i8* %ti, i8* %itf) gc "cangjie" {
  %slot = alloca i8*
  %t = call i8* @CJ_MCC_GetMTableAndOuterTI(i8* %ti, i8* %itf, i64 0, i8** %slot)
  %o = load i8*, i8** %slot
  ret i8* %o
}

; NEG-LABEL: define i8* @different_ssa(
; NEG-NOT: call i8* @CJ_MCC_GetMTableAndOuterTI
; NEG: call i8* @CJ_MCC_GetMTable(
; NEG: call i8* @CJ_MCC_GetMethodOuterTI(
define i8* @different_ssa(i8* noundef %ti, i8* noundef %itf, i8* noundef %other, i8* %unknown, i64 %n, i8** %external) gc "cangjie" {
  %t = call i8* @CJ_MCC_GetMTable(i8* %ti, i8* %itf)

  %o = call i8* @CJ_MCC_GetMethodOuterTI(i8* %other, i8* %itf, i64 0)
  ret i8* %o
}

; NEG-LABEL: define i8* @different_itf(
; NEG-NOT: call i8* @CJ_MCC_GetMTableAndOuterTI
; NEG: call i8* @CJ_MCC_GetMTable(
; NEG: call i8* @CJ_MCC_GetMethodOuterTI(
define i8* @different_itf(i8* noundef %ti, i8* noundef %itf, i8* noundef %other, i8* %unknown, i64 %n, i8** %external) gc "cangjie" {
  %t = call i8* @CJ_MCC_GetMTable(i8* %ti, i8* %itf)

  %o = call i8* @CJ_MCC_GetMethodOuterTI(i8* %ti, i8* %other, i64 0)
  ret i8* %o
}

; NEG-LABEL: define i8* @intervening_call(
; NEG-NOT: call i8* @CJ_MCC_GetMTableAndOuterTI
; NEG: call i8* @CJ_MCC_GetMTable(
; NEG: call i8* @CJ_MCC_GetMethodOuterTI(
define i8* @intervening_call(i8* noundef %ti, i8* noundef %itf, i8* noundef %other, i8* %unknown, i64 %n, i8** %external) gc "cangjie" {
  %t = call i8* @CJ_MCC_GetMTable(i8* %ti, i8* %itf)
  call void @opaque()
  %o = call i8* @CJ_MCC_GetMethodOuterTI(i8* %ti, i8* %itf, i64 0)
  ret i8* %o
}

; NEG-LABEL: define i8* @may_trap(
; NEG-NOT: call i8* @CJ_MCC_GetMTableAndOuterTI
; NEG: call i8* @CJ_MCC_GetMTable(
; NEG: call i8* @CJ_MCC_GetMethodOuterTI(
define i8* @may_trap(i8* noundef %ti, i8* noundef %itf, i8* noundef %other, i8* %unknown, i64 %n, i8** %external) gc "cangjie" {
  %t = call i8* @CJ_MCC_GetMTable(i8* %ti, i8* %itf)
  %q = udiv i64 9, %n
  %o = call i8* @CJ_MCC_GetMethodOuterTI(i8* %ti, i8* %itf, i64 0)
  ret i8* %o
}

; NEG-LABEL: define i8* @arbitrary_invariant_load(
; NEG-NOT: call i8* @CJ_MCC_GetMTableAndOuterTI
; NEG: call i8* @CJ_MCC_GetMTable(
; NEG: call i8* @CJ_MCC_GetMethodOuterTI(
define i8* @arbitrary_invariant_load(i8* noundef %ti, i8* noundef %itf, i8* noundef %other, i8* %unknown, i64 %n, i8** %external) gc "cangjie" {
  %t = call i8* @CJ_MCC_GetMTable(i8* %ti, i8* %itf)
  %q = load i8*, i8** %external, !invariant.load !0
  %o = call i8* @CJ_MCC_GetMethodOuterTI(i8* %ti, i8* %itf, i64 0)
  ret i8* %o
}

; NEG-LABEL: define i8* @volatile_table(
; NEG-NOT: call i8* @CJ_MCC_GetMTableAndOuterTI
; NEG: call i8* @CJ_MCC_GetMTable(
; NEG: call i8* @CJ_MCC_GetMethodOuterTI(
define i8* @volatile_table(i8* noundef %ti, i8* noundef %itf, i8* noundef %other, i8* %unknown, i64 %n, i8** %external) gc "cangjie" {
  %t = call i8* @CJ_MCC_GetMTable(i8* %ti, i8* %itf)
  %p = bitcast i8* %t to i8**
  %q = load volatile i8*, i8** %p
  %o = call i8* @CJ_MCC_GetMethodOuterTI(i8* %ti, i8* %itf, i64 0)
  ret i8* %o
}

; NEG-LABEL: define i8* @atomic_table(
; NEG-NOT: call i8* @CJ_MCC_GetMTableAndOuterTI
; NEG: call i8* @CJ_MCC_GetMTable(
; NEG: call i8* @CJ_MCC_GetMethodOuterTI(
define i8* @atomic_table(i8* noundef %ti, i8* noundef %itf, i8* noundef %other, i8* %unknown, i64 %n, i8** %external) gc "cangjie" {
  %t = call i8* @CJ_MCC_GetMTable(i8* %ti, i8* %itf)
  %p = bitcast i8* %t to i8**
  %q = load atomic i8*, i8** %p acquire, align 8
  %o = call i8* @CJ_MCC_GetMethodOuterTI(i8* %ti, i8* %itf, i64 0)
  ret i8* %o
}

; NEG-LABEL: define i8* @dynamic_index(
; NEG-NOT: call i8* @CJ_MCC_GetMTableAndOuterTI
; NEG: call i8* @CJ_MCC_GetMTable(
; NEG: call i8* @CJ_MCC_GetMethodOuterTI(
define i8* @dynamic_index(i8* noundef %ti, i8* noundef %itf, i8* noundef %other, i8* %unknown, i64 %n, i8** %external) gc "cangjie" {
  %t = call i8* @CJ_MCC_GetMTable(i8* %ti, i8* %itf)

  %o = call i8* @CJ_MCC_GetMethodOuterTI(i8* %ti, i8* %itf, i64 %n)
  ret i8* %o
}

; NEG-LABEL: define i8* @negative_index(
; NEG-NOT: call i8* @CJ_MCC_GetMTableAndOuterTI
; NEG: call i8* @CJ_MCC_GetMTable(
; NEG: call i8* @CJ_MCC_GetMethodOuterTI(
define i8* @negative_index(i8* noundef %ti, i8* noundef %itf, i8* noundef %other, i8* %unknown, i64 %n, i8** %external) gc "cangjie" {
  %t = call i8* @CJ_MCC_GetMTable(i8* %ti, i8* %itf)

  %o = call i8* @CJ_MCC_GetMethodOuterTI(i8* %ti, i8* %itf, i64 -1)
  ret i8* %o
}

; NEG-LABEL: define i8* @undef(
; NEG-NOT: call i8* @CJ_MCC_GetMTableAndOuterTI
; NEG: call i8* @CJ_MCC_GetMTable(
; NEG: call i8* @CJ_MCC_GetMethodOuterTI(
define i8* @undef(i8* noundef %ti, i8* noundef %itf, i8* noundef %other, i8* %unknown, i64 %n, i8** %external) gc "cangjie" {
  %t = call i8* @CJ_MCC_GetMTable(i8* undef, i8* %itf)

  %o = call i8* @CJ_MCC_GetMethodOuterTI(i8* undef, i8* %itf, i64 0)
  ret i8* %o
}

; NEG-LABEL: define i8* @poison(
; NEG-NOT: call i8* @CJ_MCC_GetMTableAndOuterTI
; NEG: call i8* @CJ_MCC_GetMTable(
; NEG: call i8* @CJ_MCC_GetMethodOuterTI(
define i8* @poison(i8* noundef %ti, i8* noundef %itf, i8* noundef %other, i8* %unknown, i64 %n, i8** %external) gc "cangjie" {
  %t = call i8* @CJ_MCC_GetMTable(i8* poison, i8* %itf)

  %o = call i8* @CJ_MCC_GetMethodOuterTI(i8* poison, i8* %itf, i64 0)
  ret i8* %o
}

; NEG-LABEL: define i8* @unknown_value(
; NEG-NOT: call i8* @CJ_MCC_GetMTableAndOuterTI
; NEG: call i8* @CJ_MCC_GetMTable(
; NEG: call i8* @CJ_MCC_GetMethodOuterTI(
define i8* @unknown_value(i8* noundef %ti, i8* noundef %itf, i8* noundef %other, i8* %unknown, i64 %n, i8** %external) gc "cangjie" {
  %t = call i8* @CJ_MCC_GetMTable(i8* %unknown, i8* %itf)

  %o = call i8* @CJ_MCC_GetMethodOuterTI(i8* %unknown, i8* %itf, i64 0)
  ret i8* %o
}

; NEG-LABEL: define i8* @tail(
; NEG-NOT: call i8* @CJ_MCC_GetMTableAndOuterTI
; NEG: call i8* @CJ_MCC_GetMTable(
; NEG: call i8* @CJ_MCC_GetMethodOuterTI(
define i8* @tail(i8* noundef %ti, i8* noundef %itf, i8* noundef %other, i8* %unknown, i64 %n, i8** %external) gc "cangjie" {
  %t = call i8* @CJ_MCC_GetMTable(i8* %ti, i8* %itf)

  %o = tail call i8* @CJ_MCC_GetMethodOuterTI(i8* %ti, i8* %itf, i64 0)
  ret i8* %o
}

; NEG-LABEL: define i8* @bundle(
; NEG-NOT: call i8* @CJ_MCC_GetMTableAndOuterTI
; NEG: call i8* @CJ_MCC_GetMTable(
; NEG: call i8* @CJ_MCC_GetMethodOuterTI(
define i8* @bundle(i8* noundef %ti, i8* noundef %itf, i8* noundef %other, i8* %unknown, i64 %n, i8** %external) gc "cangjie" {
  %t = call i8* @CJ_MCC_GetMTable(i8* %ti, i8* %itf)

  %o = call i8* @CJ_MCC_GetMethodOuterTI(i8* %ti, i8* %itf, i64 0) [ "deopt"(i32 1) ]
  ret i8* %o
}

; NEG-LABEL: define i8* @abi_attribute(
; NEG-NOT: call i8* @CJ_MCC_GetMTableAndOuterTI
; NEG: call i8* @CJ_MCC_GetMTable(
; NEG: call i8* @CJ_MCC_GetMethodOuterTI(
define i8* @abi_attribute(i8* noundef %ti, i8* noundef %itf, i8* noundef %other, i8* %unknown, i64 %n, i8** %external) gc "cangjie" {
  %t = call i8* @CJ_MCC_GetMTable(i8* %ti, i8* %itf)

  %o = call i8* @CJ_MCC_GetMethodOuterTI(i8* inreg %ti, i8* %itf, i64 0)
  ret i8* %o
}

; NEG-LABEL: define i8* @cross_block(
; NEG: call i8* @CJ_MCC_GetMTable(
; NEG: call i8* @CJ_MCC_GetMethodOuterTI(
define i8* @cross_block(i8* noundef %ti, i8* noundef %itf) gc "cangjie" {
  %t = call i8* @CJ_MCC_GetMTable(i8* %ti, i8* %itf)
  br label %next
next:
  %o = call i8* @CJ_MCC_GetMethodOuterTI(i8* %ti, i8* %itf, i64 0)
  ret i8* %o
}
; NEG-LABEL: define i8* @invoke_outer(
; NEG: call i8* @CJ_MCC_GetMTable(
; NEG: invoke i8* @CJ_MCC_GetMethodOuterTI(
define i8* @invoke_outer(i8* noundef %ti, i8* noundef %itf) gc "cangjie" personality i32 (...)* @__gxx_personality_v0 {
  %t = call i8* @CJ_MCC_GetMTable(i8* %ti, i8* %itf)
  %o = invoke i8* @CJ_MCC_GetMethodOuterTI(i8* %ti, i8* %itf, i64 0) to label %ok unwind label %bad
ok:
  ret i8* %o
bad:
  %lp = landingpad { i8*, i32 } cleanup
  resume { i8*, i32 } %lp
}
!0 = !{}
!1 = !{i64 2}
