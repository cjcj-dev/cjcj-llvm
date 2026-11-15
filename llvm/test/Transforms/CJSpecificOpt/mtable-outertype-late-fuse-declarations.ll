; RUN: split-file %s %t
; RUN: opt -passes=cj-specific-opt -verify-each -S %t/readnone.ll | FileCheck %s --check-prefix=KEEP
; RUN: opt -passes=cj-specific-opt -verify-each -S %t/wrong-type.ll | FileCheck %s --check-prefix=KEEP
; RUN: opt -passes=cj-specific-opt -verify-each -S %t/unmarked.ll | FileCheck %s --check-prefix=KEEP
; RUN: opt -passes=cj-specific-opt -verify-each -S %t/unmarked-fused.ll | FileCheck %s --check-prefix=KEEP
; RUN: opt -passes=cj-specific-opt -verify-each -S %t/other-as.ll | FileCheck %s --check-prefix=AS
; RUN: opt -passes=cj-specific-opt -verify-each -S %t/fresh.ll | FileCheck %s --check-prefix=FRESH
; RUN: opt -passes=cj-runtime-lowering,cj-specific-opt -verify-each -S %t/lowered.ll | FileCheck %s --check-prefix=LOWERED
;
; An existing fused declaration is not repaired by copying attributes or a
; function-pointer cast. Unmarked names are not evidence of the runtime ABI.
; KEEP-LABEL: define i8* @test(
; KEEP: call i8* @CJ_MCC_GetMTable(
; KEEP-NEXT: %o = call i8* @CJ_MCC_GetMethodOuterTI(
; AS-LABEL: define i8* @test(
; AS: call i8* @CJ_MCC_GetMTable(i8 addrspace(1)* %ti
; AS-NEXT: %o = call i8* @CJ_MCC_GetMethodOuterTI(i8 addrspace(1)* %ti
; FRESH-LABEL: define i8* @test(
; FRESH: call i8* @CJ_MCC_GetMTableAndOuterTI(i8* %ti, i8* %itf, i64 0, i8** %mtable.outer.ti)
; FRESH: declare i8* @CJ_MCC_GetMTableAndOuterTI(i8*, i8*, i64, i8**) #[[ATTR:[0-9]+]]
; FRESH: attributes #[[ATTR]] = { "cj-runtime" "gc-leaf-function" }

;--- readnone.ll
declare i8* @CJ_MCC_GetMTable(i8*, i8*) #0
declare i8* @CJ_MCC_GetMethodOuterTI(i8*, i8*, i64) #0
declare i8* @CJ_MCC_GetMTableAndOuterTI(i8*, i8*, i64, i8**) readnone
attributes #0 = { "cj-runtime" "gc-leaf-function" }
define i8* @test(i8* noundef %ti, i8* noundef %itf) gc "cangjie" {
  %t = call i8* @CJ_MCC_GetMTable(i8* %ti, i8* %itf)
  %o = call i8* @CJ_MCC_GetMethodOuterTI(i8* %ti, i8* %itf, i64 0)
  ret i8* %o
}
;--- wrong-type.ll
declare i8* @CJ_MCC_GetMTable(i8*, i8*) #0
declare i8* @CJ_MCC_GetMethodOuterTI(i8*, i8*, i64) #0
declare i8* @CJ_MCC_GetMTableAndOuterTI(i8*, i8*, i32, i8**)
attributes #0 = { "cj-runtime" "gc-leaf-function" }
define i8* @test(i8* noundef %ti, i8* noundef %itf) gc "cangjie" {
  %t = call i8* @CJ_MCC_GetMTable(i8* %ti, i8* %itf)
  %o = call i8* @CJ_MCC_GetMethodOuterTI(i8* %ti, i8* %itf, i64 0)
  ret i8* %o
}
;--- unmarked.ll
declare i8* @CJ_MCC_GetMTable(i8*, i8*)
declare i8* @CJ_MCC_GetMethodOuterTI(i8*, i8*, i64)
define i8* @test(i8* noundef %ti, i8* noundef %itf) gc "cangjie" {
  %t = call i8* @CJ_MCC_GetMTable(i8* %ti, i8* %itf)
  %o = call i8* @CJ_MCC_GetMethodOuterTI(i8* %ti, i8* %itf, i64 0)
  ret i8* %o
}
;--- other-as.ll
declare i8* @CJ_MCC_GetMTable(i8 addrspace(1)*, i8*) #0
declare i8* @CJ_MCC_GetMethodOuterTI(i8 addrspace(1)*, i8*, i64) #0
attributes #0 = { "cj-runtime" "gc-leaf-function" }
define i8* @test(i8 addrspace(1)* noundef %ti, i8* noundef %itf) gc "cangjie" {
  %t = call i8* @CJ_MCC_GetMTable(i8 addrspace(1)* %ti, i8* %itf)
  %o = call i8* @CJ_MCC_GetMethodOuterTI(i8 addrspace(1)* %ti, i8* %itf, i64 0)
  ret i8* %o
}
;--- unmarked-fused.ll
declare i8* @CJ_MCC_GetMTable(i8*, i8*) #0
declare i8* @CJ_MCC_GetMethodOuterTI(i8*, i8*, i64) #0
declare i8* @CJ_MCC_GetMTableAndOuterTI(i8*, i8*, i64, i8**)
attributes #0 = { "cj-runtime" "gc-leaf-function" }
define i8* @test(i8* noundef %ti, i8* noundef %itf) gc "cangjie" {
  %t = call i8* @CJ_MCC_GetMTable(i8* %ti, i8* %itf)
  %o = call i8* @CJ_MCC_GetMethodOuterTI(i8* %ti, i8* %itf, i64 0)
  ret i8* %o
}
;--- fresh.ll
declare i8* @CJ_MCC_GetMTable(i8*, i8*) #0
declare i8* @CJ_MCC_GetMethodOuterTI(i8*, i8*, i64) #0
attributes #0 = { readnone speculatable willreturn "cj-runtime" "gc-leaf-function" }
define i8* @test(i8* noundef %ti, i8* noundef %itf) gc "cangjie" {
  %t = call i8* @CJ_MCC_GetMTable(i8* %ti, i8* %itf)
  %o = call i8* @CJ_MCC_GetMethodOuterTI(i8* %ti, i8* %itf, i64 0)
  ret i8* %o
}

;--- lowered.ll
; Exercise the normal producer, including the implicit nounwind attribute on
; the already-used fused intrinsic's runtime declaration.
declare i8* @llvm.cj.get.mtable.func(i8*, i8*, i64)
declare i8* @llvm.cj.get.method.outertype(i8*, i8*, i64)
declare { i8*, i8* } @llvm.cj.get.mtable.func.outertype(i8*, i8*, i64)
; LOWERED-LABEL: define i8* @legacy_pair(
; LOWERED: [[TABLE:%.*]] = call i8* @CJ_MCC_GetMTableAndOuterTI(i8* %ti, i8* %itf, i64 0,
; LOWERED-NOT: call i8* @CJ_MCC_GetMTable(
; LOWERED-NOT: call i8* @CJ_MCC_GetMethodOuterTI(
; LOWERED: load i8*, i8**
; LOWERED: ret i8*
define i8* @legacy_pair(i8* noundef %ti, i8* noundef %itf) gc "cangjie" {
  %method = call i8* @llvm.cj.get.mtable.func(i8* %ti, i8* %itf, i64 0)
  %outer = call i8* @llvm.cj.get.method.outertype(i8* %ti, i8* %itf, i64 0)
  %fn = bitcast i8* %method to i8* (i8*)*
  %result = call i8* %fn(i8* %outer)
  ret i8* %result
}
; LOWERED-LABEL: define { i8*, i8* } @existing(
; LOWERED: call i8* @CJ_MCC_GetMTableAndOuterTI(
define { i8*, i8* } @existing(i8* %ti, i8* %itf) gc "cangjie" {
  %pair = call { i8*, i8* } @llvm.cj.get.mtable.func.outertype(i8* %ti, i8* %itf, i64 0)
  ret { i8*, i8* } %pair
}
