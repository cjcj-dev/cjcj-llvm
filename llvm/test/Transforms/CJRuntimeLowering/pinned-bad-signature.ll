; RUN: not --crash opt -passes=cj-runtime-lowering -disable-output < %s 2>&1 | FileCheck %s
; CHECK: LLVM ERROR: incompatible Cangjie runtime declaration: CJ_MCC_NewPinnedObject
declare i8 addrspace(1)* @CJ_MCC_NewPinnedObject(i8*, i32, i1)
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
define i8 addrspace(1)* @pinned(i8* %ti) {
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* %ti, i32 32), !MallocType !0
  ret i8 addrspace(1)* %obj
}
!0 = !{!"Future"}
