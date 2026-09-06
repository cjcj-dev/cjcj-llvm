; RUN: opt -passes=cj-ir-verifier < %s -disable-output 2>&1 | FileCheck %s

%ref_payload = type { i8 addrspace(1)* }
@zeros = internal constant [8 x i8] zeroinitializer

; CHECK: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [unknown-payload:report]
; CHECK-NEXT: call void @llvm.memcpy.p1i8.p0i8.i64
; CHECK: in function c2_as0_source_refdst
; CHECK-NOT: LLVM ERROR
define void @c2_as0_source_refdst(i8 addrspace(1)* %obj) gc "cangjie" {
entry:
  %typed = bitcast i8 addrspace(1)* %obj to %ref_payload addrspace(1)*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %obj,
      i8* getelementptr inbounds ([8 x i8], [8 x i8]* @zeros, i32 0, i32 0),
      i64 8, i1 false)
  ret void
}

declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)
