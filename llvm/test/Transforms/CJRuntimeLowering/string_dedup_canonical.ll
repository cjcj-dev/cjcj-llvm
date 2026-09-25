; RUN: opt < %s -passes=cj-runtime-lowering -S | FileCheck %s --check-prefix=DEDUP
; RUN: opt < %s -passes=cj-runtime-lowering -S | FileCheck %s --check-prefix=FILL

declare i8 addrspace(1)* @llvm.cj.string.dedup.canonical(i8*, i8 addrspace(1)*)
declare i8 addrspace(1)* @llvm.cj.fill.in.stack.trace(i8*, i8 addrspace(1)*)

define i8 addrspace(1)* @canonicalize(i8* %ti, i8 addrspace(1)* %candidate) {
; DEDUP-LABEL: @canonicalize(
; DEDUP: call i8 addrspace(1)* @CJ_MCC_StringDedupCanonical(i8* %ti, i8 addrspace(1)* %candidate)
; DEDUP: declare i8 addrspace(1)* @CJ_MCC_StringDedupCanonical(i8*, i8 addrspace(1)*) [[RT:#[0-9]+]]
; DEDUP: declare i8 addrspace(1)* @CJ_MCC_FillInStackTrace(i8*, i8 addrspace(1)*) [[RT]]
; DEDUP: attributes [[RT]] = { nounwind "cj-runtime" }
  %backing = call i8 addrspace(1)* @llvm.cj.string.dedup.canonical(i8* %ti, i8 addrspace(1)* %candidate)
  ret i8 addrspace(1)* %backing
}

define i8 addrspace(1)* @fill_still(i8* %ti, i8 addrspace(1)* %exception) {
; FILL-LABEL: @fill_still(
; FILL: call i8 addrspace(1)* @CJ_MCC_FillInStackTrace(i8* %ti, i8 addrspace(1)* %exception)
  %trace = call i8 addrspace(1)* @llvm.cj.fill.in.stack.trace(i8* %ti, i8 addrspace(1)* %exception)
  ret i8 addrspace(1)* %trace
}
