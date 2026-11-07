; The fused mtable/outer-TypeInfo lookup needs a constant method index, as
; llvm.cj.get.mtable.func does.
; RUN: not --crash opt -passes=cj-ir-verifier < %s -disable-output 2>&1 | FileCheck %s
; CHECK: Called Function index should be constant int!
; CHECK-NEXT: call { i8*, i8* } @llvm.cj.get.mtable.func.outertype(i8* %ti, i8* %itf, i64 %idx)

declare { i8*, i8* } @llvm.cj.get.mtable.func.outertype(i8*, i8*, i64)

define i8* @nonconst(i8* %ti, i8* %itf, i64 %idx) gc "cangjie" {
entry:
  %r = call { i8*, i8* } @llvm.cj.get.mtable.func.outertype(i8* %ti, i8* %itf, i64 %idx)
  %fp = extractvalue { i8*, i8* } %r, 0
  ret i8* %fp
}
