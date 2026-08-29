; RUN: llc --cangjie-pipeline -mtriple=x86_64 -print-after=cj-barrier-lowering \
; RUN:   -o /dev/null < %s 2>&1 | FileCheck %s

%payload = type { i64, i8 addrspace(1)* }

; Null base alone is not proof: an unknown AS1 struct destination must use the
; MCC producer that publishes coloured heap reference words.
; CHECK-LABEL: define void @write_struct_null_base_unknown(
; CHECK-NOT: call void @llvm.memcpy
; CHECK: call void @CJ_MCC_WriteStructField
; CHECK-NOT: call void @llvm.memcpy
; CHECK: ret void
define void @write_struct_null_base_unknown(i8 addrspace(1)* %dst,
                                            i8* %src) gc "cangjie" {
entry:
  call void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)* null,
                                         i8 addrspace(1)* %dst,
                                         i8* %src, i64 16), !AggType !0
  ret void
}

; An AS0 alloca is a structural non-heap proof. Keep the root/stack copy raw.
; CHECK-LABEL: define void @write_struct_null_base_alloca(
; CHECK-NOT: call void @CJ_MCC_WriteStructField
; CHECK: call void @llvm.memcpy
; CHECK-NOT: call void @CJ_MCC_WriteStructField
; CHECK: ret void
; STACK-LABEL: define void @write_struct_null_base_alloca(
; STACK-NOT: call void @CJ_MCC_WriteStructField
; STACK: call void @llvm.memcpy
; STACK-NOT: call void @CJ_MCC_WriteStructField
; STACK: ret void
define void @write_struct_null_base_alloca(i8* %src) gc "cangjie" {
entry:
  %slot = alloca %payload, align 8
  %slot.i8 = bitcast %payload* %slot to i8*
  %slot.as1 = addrspacecast i8* %slot.i8 to i8 addrspace(1)*
  call void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)* null,
                                         i8 addrspace(1)* %slot.as1,
                                         i8* %src, i64 16), !AggType !0
  ret void
}

declare void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)*,
                                          i8 addrspace(1)*, i8*, i64)

!0 = !{!"payload"}
