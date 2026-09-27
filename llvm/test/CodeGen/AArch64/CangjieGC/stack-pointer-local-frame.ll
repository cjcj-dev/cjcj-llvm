; RUN: llc -O2 --cangjie-pipeline -cj-stack-grow=false -mtriple=aarch64-unknown-linux-gnu -stop-after=localstackalloc < %s | FileCheck %s
; RUN: llc -O2 --cangjie-pipeline -cj-stack-grow=true -mtriple=aarch64-unknown-linux-gnu -stop-after=localstackalloc < %s | FileCheck %s
;
; Two out-of-range uses make a virtual frame-base register profitable. Cangjie
; stack-pointer analysis needs the alloca frame indices to remain visible,
; independently of whether the runtime can grow stacks.
; CHECK-LABEL: name: large_frame
; CHECK: STRBBui {{.*}}, %stack.[[A:[0-9]+]].a, 0
; CHECK: STRBBui {{.*}}, %stack.[[A]].a, 0

declare token @llvm.cj.gc.statepoint(...)
declare void @consume(i8*, i8*)
define void @large_frame() gc "cangjie" {
  %a = alloca [8192 x i8], align 16
  %b = alloca [8192 x i8], align 16
  %ap = getelementptr [8192 x i8], [8192 x i8]* %a, i64 0, i64 0
  %bp = getelementptr [8192 x i8], [8192 x i8]* %b, i64 0, i64 0
  store volatile i8 3, i8* %ap
  store volatile i8 1, i8* %ap
  store volatile i8 2, i8* %bp
  %t = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, void (i8*, i8*)* @consume, i32 2, i32 0, i8* %ap, i8* %bp)
  ret void
}
