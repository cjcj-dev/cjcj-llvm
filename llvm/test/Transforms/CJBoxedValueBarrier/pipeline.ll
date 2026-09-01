; RUN: opt -passes='default<O0>' --cangjie-pipeline -S < %s | FileCheck %s

; This test enters through the product Cangjie pipeline.  CJBoxedValueBarrier
; must rewrite the memcpy before CJIRVerifier runs, and CJRuntimeLowering must
; then lower the replacement intrinsic to the existing runtime entry.
; CHECK-LABEL: define i8 addrspace(1)* @box_in_product_pipeline(
; CHECK-NOT: llvm.memcpy.p1i8.p0i8.i32
; CHECK: call void @CJ_MCC_WriteGenericPayload(i8 addrspace(1)* %object, i8* %source, i32 %size)
define i8 addrspace(1)* @box_in_product_pipeline(i8* %type.info, i8* %source,
                                                 i32 %size) gc "cangjie" {
entry:
  %object = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* %type.info,
                                                         i32 %size)
  %object.fields = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.slot = getelementptr i8*, i8* addrspace(1)* %object.fields, i32 1
  %payload = bitcast i8* addrspace(1)* %payload.slot to i8 addrspace(1)*
  call void @llvm.memcpy.p1i8.p0i8.i32(i8 addrspace(1)* %payload,
                                       i8* %source, i32 %size, i1 false)
  ret i8 addrspace(1)* %object
}

declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare void @llvm.memcpy.p1i8.p0i8.i32(i8 addrspace(1)*, i8*, i32, i1)
