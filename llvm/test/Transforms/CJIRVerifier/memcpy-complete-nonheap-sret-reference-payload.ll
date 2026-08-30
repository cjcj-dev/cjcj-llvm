; RUN: opt -passes=cj-ir-verifier < %s -disable-output

%stack_trace_data = type { i8 addrspace(1)*, i8 addrspace(1)*,
                           i8 addrspace(1)*, i64 }

; Mirrors _CNat23decodeStackTraceWrapperL_E: a complete typed stack temporary
; is copied into a typed non-heap sret slot.
define void @allow_complete_nonheap_sret_memcpy_with_reference_payload(
    %stack_trace_data* noalias sret(%stack_trace_data) %result)
    gc "cangjie" {
entry:
  %tmp = alloca %stack_trace_data, align 8
  %result.i8 = bitcast %stack_trace_data* %result to i8*
  %tmp.i8 = bitcast %stack_trace_data* %tmp to i8*
  call void @llvm.cj.memset(i8* %tmp.i8, i8 0, i64 32, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %result.i8, i8* %tmp.i8,
                                       i64 32, i1 false)
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
