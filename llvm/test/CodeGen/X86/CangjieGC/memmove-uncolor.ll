; RUN: llc --cangjie-pipeline -mtriple=x86_64 -print-after=cj-barrier-lowering \
; RUN:   -o /dev/null < %s 2>&1 | FileCheck %s

; zAddress.inline.hpp:609-614 uncolors only a load-good zpointer, by the
; published load shift. CreateCopyTo's llvm.memmove operands here are
; function arguments: plain addresses, not colored loads. Bare memmove is
; outside the barrier set (CJBarrierLowering.cpp:1404-1406). Lowering must
; not insert llvm.ptrmask or a shift uncolor. P01 rejects both
; (CJIRVerifier.cpp:465, CJIRVerifier.cpp:947).

define void @array_byte_copy(i8 addrspace(1)* %dst, i8 addrspace(1)* %src,
                             i64 %len) gc "cangjie" {
; CHECK-LABEL: define void @array_byte_copy(
; CHECK-NOT: llvm.ptrmask
; CHECK-NOT: @g_cjLoadShift
; CHECK: call void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)* align 1 %dst, i8 addrspace(1)* align 1 %src, i64 %len, i1 false)
; CHECK-NOT: llvm.ptrmask
; CHECK-NOT: @g_cjLoadShift
; CHECK: ret void
entry:
  call void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)* align 1 %dst,
                                       i8 addrspace(1)* align 1 %src,
                                       i64 %len, i1 false)
  ret void
}

define void @array_byte_copy_as0_untouched(i8* %dst, i8* %src, i64 %len) gc "cangjie" {
; CHECK-LABEL: define void @array_byte_copy_as0_untouched(
; CHECK-NOT: llvm.ptrmask
; CHECK-NOT: @g_cjLoadShift
; CHECK: call void @llvm.memmove.p0i8.p0i8.i64(i8* align 1 %dst, i8* align 1 %src, i64 %len, i1 false)
entry:
  call void @llvm.memmove.p0i8.p0i8.i64(i8* align 1 %dst, i8* align 1 %src,
                                       i64 %len, i1 false)
  ret void
}

declare void @llvm.memmove.p1i8.p1i8.i64(i8 addrspace(1)*, i8 addrspace(1)*, i64, i1)
declare void @llvm.memmove.p0i8.p0i8.i64(i8*, i8*, i64, i1)
