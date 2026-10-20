; RUN: not --crash opt -passes=cj-runtime-lowering -disable-output < %s 2>&1 | FileCheck %s
; CHECK: LLVM ERROR: incompatible Cangjie finalizer call signature
declare i8 addrspace(1)* @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)*)
define i8 addrspace(1)* @bad_call(i8* %obj) {
  %r = call i8 addrspace(1)* bitcast (i8 addrspace(1)* (i8 addrspace(1)*)* @CJ_MCC_OnFinalizerCreated to i8 addrspace(1)* (i8*)*)(i8* %obj)
  ret i8 addrspace(1)* %r
}
