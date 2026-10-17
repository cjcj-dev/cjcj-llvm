; RUN: opt -S -passes=cj-runtime-lowering %s | FileCheck %s
; TraceCapture is a GC pointer result; three native TypeInfo pointers precede the owned message.
declare i8 addrspace(1)* @llvm.cj.fill.in.stack.trace(i8*, i8*, i8*, i8 addrspace(1)*)
define i8 addrspace(1)* @capture(i8* %capture, i8* %frames, i8* %bytes, i8 addrspace(1)* %message) {
; CHECK-LABEL: define i8 addrspace(1)* @capture
; CHECK: call i8 addrspace(1)* @CJ_MCC_FillInStackTrace(i8* %capture, i8* %frames, i8* %bytes, i8 addrspace(1)* %message)
  %result = call i8 addrspace(1)* @llvm.cj.fill.in.stack.trace(i8* %capture, i8* %frames, i8* %bytes, i8 addrspace(1)* %message)
  ret i8 addrspace(1)* %result
}
