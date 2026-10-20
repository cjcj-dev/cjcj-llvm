; RUN: not --crash opt -passes=cj-runtime-lowering -disable-output < %s 2>&1 | FileCheck %s
; CHECK: LLVM ERROR: incompatible Cangjie runtime declaration: CJ_MCC_OnFinalizerCreated
; No silent getOrInsertFunction bitcast from the old void-return ABI.
declare void @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)*)
