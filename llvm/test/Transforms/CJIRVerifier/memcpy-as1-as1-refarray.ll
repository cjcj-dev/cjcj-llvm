; RUN: not not opt -passes=cj-ir-verifier < %s -disable-output 2>&1 | FileCheck %s -check-prefixes=CHECK,ABORT

%ArrayBase = type { i64 }
%RefElement = type { i8 addrspace(1)* }
%ArrayLayout.Ref = type { %ArrayBase, [0 x %RefElement] }

; CHECK: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; CHECK-NEXT: call void @llvm.memmove.p1i8.p1i8.i64
; CHECK: in function as1_as1_refarray_copy
define void @as1_as1_refarray_copy(i8 addrspace(1)* %dst.base,
                                   i8 addrspace(1)* %src.base,
                                   i64 %size) gc "cangjie" {
entry:
  %dst.layout = bitcast i8 addrspace(1)* %dst.base to %ArrayLayout.Ref addrspace(1)*
  %dst.payload = getelementptr inbounds %ArrayLayout.Ref, %ArrayLayout.Ref addrspace(1)* %dst.layout, i32 0, i32 1
  %dst = bitcast [0 x %RefElement] addrspace(1)* %dst.payload to i8 addrspace(1)*
  %src.layout = bitcast i8 addrspace(1)* %src.base to %ArrayLayout.Ref addrspace(1)*
  %src.payload = getelementptr inbounds %ArrayLayout.Ref, %ArrayLayout.Ref addrspace(1)* %src.layout, i32 0, i32 1
  %src = bitcast [0 x %RefElement] addrspace(1)* %src.payload to i8 addrspace(1)*
  call void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)* %dst, i8 addrspace(1)* %src,
                                        i64 %size, i1 false)
  ret void
}

declare void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)*, i8 addrspace(1)*, i64, i1)

; ABORT: LLVM ERROR: Broken function found, compilation aborted
; ABORT: error: Aborted
