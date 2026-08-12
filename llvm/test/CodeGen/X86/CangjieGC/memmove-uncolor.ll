; RUN: llc --cangjie-pipeline -mtriple=x86_64 -print-after=cj-barrier-lowering \
; RUN:   -o /dev/null < %s 2>&1 | FileCheck %s

; CreateCopyTo emits llvm.memmove on addrspace(1) payload interiors.
; cj-barrier-lowering must strip colour (low 48 bits) with llvm.ptrmask before
; the transfer.

define void @array_byte_copy(i8 addrspace(1)* %dst, i8 addrspace(1)* %src,
                             i64 %len) gc "cangjie" {
; CHECK-LABEL: define void @array_byte_copy(
; CHECK: [[DST_PLAIN:%.*]] = call i8 addrspace(1)* @llvm.ptrmask.p1i8.i64(i8 addrspace(1)* %dst, i64 281474976710655)
; CHECK: [[SRC_PLAIN:%.*]] = call i8 addrspace(1)* @llvm.ptrmask.p1i8.i64(i8 addrspace(1)* %src, i64 281474976710655)
; CHECK: call void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)* align 1 [[DST_PLAIN]], i8 addrspace(1)* align 1 [[SRC_PLAIN]], i64 %len, i1 false)
entry:
  call void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)* align 1 %dst,
                                       i8 addrspace(1)* align 1 %src,
                                       i64 %len, i1 false)
  ret void
}

define void @array_byte_copy_as0_untouched(i8* %dst, i8* %src, i64 %len) gc "cangjie" {
; CHECK-LABEL: define void @array_byte_copy_as0_untouched(
; CHECK-NOT: llvm.ptrmask
; CHECK: call void @llvm.memmove.p0i8.p0i8.i64(i8* align 1 %dst, i8* align 1 %src, i64 %len, i1 false)
entry:
  call void @llvm.memmove.p0i8.p0i8.i64(i8* align 1 %dst, i8* align 1 %src,
                                       i64 %len, i1 false)
  ret void
}

declare void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)*, i8 addrspace(1)*, i64, i1)
declare void @llvm.memmove.p0i8.p0i8.i64(i8*, i8*, i64, i1)
