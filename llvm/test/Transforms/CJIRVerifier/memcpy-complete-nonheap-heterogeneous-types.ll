; RUN: not not opt -passes=cj-ir-verifier < %s -disable-output 2>&1 | FileCheck %s

; CHECK: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.

%stack_trace_data = type { i8 addrspace(1)*, i8 addrspace(1)*,
                           i8 addrspace(1)*, i64 }
%same_size_alias = type { i8 addrspace(1)*, i64, i8 addrspace(1)*, i64 }

; Complete typed p0<-p0 copies of equal allocsize are non-heap even when the
; recovered object types differ and the payload contains GC pointers.
define void @reject_complete_nonheap_heterogeneous_types_with_mismatched_gc_layout() gc "cangjie" {
entry:
  %dst = alloca %stack_trace_data, align 8
  %src = alloca %same_size_alias, align 8
  %dst.i8 = bitcast %stack_trace_data* %dst to i8*
  %src.i8 = bitcast %same_size_alias* %src to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 32, i1 false)
  call void @llvm.cj.memset(i8* %src.i8, i8 0, i64 32, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8,
                                       i64 32, i1 false)
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
