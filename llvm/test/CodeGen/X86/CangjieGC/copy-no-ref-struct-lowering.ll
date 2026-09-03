; RUN: llc --cangjie-pipeline -mtriple=x86_64 -print-after=cj-barrier-lowering \
; RUN:   -o /dev/null < %s 2>&1 | FileCheck %s

%Plain = type { i8*, i64 }

; CHECK-LABEL: define void @lower_no_reference_struct_copy(
; CHECK-NOT: llvm.cj.copy.no.ref.struct
; CHECK: call void @llvm.memcpy.p0i8.p0i8.i64(i8* align 8 %dst, i8* align 8 %src, i64 16, i1 false)
; CHECK-NOT: llvm.cj.copy.no.ref.struct
; CHECK: ret void
define void @lower_no_reference_struct_copy(i8* %dst, i8* %src) gc "cangjie" {
entry:
  call void @llvm.cj.copy.no.ref.struct(i8* align 8 %dst, i8* align 8 %src,
                                        i64 16), !AggType !0
  ret void
}

declare void @llvm.cj.copy.no.ref.struct(i8*, i8*, i64)
!0 = !{!"Plain"}
