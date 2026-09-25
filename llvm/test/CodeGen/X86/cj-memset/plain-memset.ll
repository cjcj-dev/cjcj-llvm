; RUN: llc -mtriple=x86_64 -O0 -enable-gc-fast-path=false -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O0 -enable-gc-fast-path=false -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; Standard llvm.memset is already the form SelectionDAGBuilder consumes.
; Both the direct entry and --cangjie-pipeline must keep it. Cutting the
; cj.memset rewrite must not fail this input.
target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
%Plain = type { i8 addrspace(1)* }

; CHECK-LABEL: define void @stack_init()
; CHECK: call void @llvm.memset.p0i8.i64(i8* %init, i8 0, i64 8, i1 false)
; CHECK: ret void
define void @stack_init() gc "cangjie" {
  %plain = alloca %Plain
  %init = bitcast %Plain* %plain to i8*
  call void @llvm.memset.p0i8.i64(i8* %init, i8 0, i64 8, i1 false)
  ret void
}

declare void @llvm.memset.p0i8.i64(i8* nocapture writeonly, i8, i64, i1 immarg)
