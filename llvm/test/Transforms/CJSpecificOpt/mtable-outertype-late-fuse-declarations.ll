; RUN: split-file %s %t
; RUN: opt -passes=cj-specific-opt -verify-each -S %t/readnone.ll | FileCheck %s --check-prefix=KEEP
; RUN: opt -passes=cj-specific-opt -verify-each -S %t/wrong-type.ll | FileCheck %s --check-prefix=KEEP
; RUN: opt -passes=cj-specific-opt -verify-each -S %t/unmarked.ll | FileCheck %s --check-prefix=KEEP
; RUN: opt -passes=cj-specific-opt -verify-each -S %t/other-as.ll | FileCheck %s --check-prefix=AS
; RUN: opt -passes=cj-specific-opt -verify-each -S %t/fresh.ll | FileCheck %s --check-prefix=FRESH
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
;--- fresh.ll
declare i8* @CJ_MCC_GetMTable(i8*, i8*) #0
declare i8* @CJ_MCC_GetMethodOuterTI(i8*, i8*, i64) #0
attributes #0 = { readnone speculatable willreturn "cj-runtime" "gc-leaf-function" }
define i8* @test(i8* noundef %ti, i8* noundef %itf) gc "cangjie" {
  %t = call i8* @CJ_MCC_GetMTable(i8* %ti, i8* %itf)
  %o = call i8* @CJ_MCC_GetMethodOuterTI(i8* %ti, i8* %itf, i64 0)
  ret i8* %o
}
