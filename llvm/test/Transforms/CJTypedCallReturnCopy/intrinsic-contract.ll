; RUN: split-file %s %t
; RUN: opt -passes=cj-ir-verifier -disable-output < %t/valid.ll
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output < %t/missing-metadata.ll 2>&1 | FileCheck %s --check-prefixes=MISSING,ABORT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output < %t/unknown-type.ll 2>&1 | FileCheck %s --check-prefixes=UNKNOWN,ABORT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output < %t/as1-field.ll 2>&1 | FileCheck %s --check-prefixes=AS1,ABORT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output < %t/size-mismatch.ll 2>&1 | FileCheck %s --check-prefixes=SIZE,ABORT
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output < %t/dynamic-size.ll 2>&1 | FileCheck %s --check-prefixes=DYNAMIC,ABORT

; MISSING: llvm.cj.copy.no.ref.struct has no AggType metadata.
; MISSING: in function missing_metadata
; UNKNOWN: llvm.cj.copy.no.ref.struct AggType must resolve to a sized concrete struct.
; UNKNOWN: in function unknown_type
; AS1: llvm.cj.copy.no.ref.struct AggType contains an AS1 field.
; AS1: in function reject_as1_field
; SIZE: llvm.cj.copy.no.ref.struct size must equal AggType alloc size.
; SIZE: in function reject_size_mismatch
; DYNAMIC: llvm.cj.copy.no.ref.struct size must be a nonzero constant.
; DYNAMIC: in function reject_dynamic_size
; ABORT: LLVM ERROR: Broken function found, compilation aborted
; ABORT: error: Aborted

;--- valid.ll
%Plain = type { i8*, i64 }
define void @valid(i8* %dst, i8* %src) gc "cangjie" {
entry:
  call void @llvm.cj.copy.no.ref.struct(i8* %dst, i8* %src, i64 16), !AggType !0
  ret void
}
declare void @llvm.cj.copy.no.ref.struct(i8*, i8*, i64)
!0 = !{!"Plain"}

;--- missing-metadata.ll
%Plain = type { i8*, i64 }
define void @missing_metadata(i8* %dst, i8* %src) gc "cangjie" {
entry:
  call void @llvm.cj.copy.no.ref.struct(i8* %dst, i8* %src, i64 16)
  ret void
}
declare void @llvm.cj.copy.no.ref.struct(i8*, i8*, i64)

;--- unknown-type.ll
%Plain = type { i8*, i64 }
define void @unknown_type(i8* %dst, i8* %src) gc "cangjie" {
entry:
  call void @llvm.cj.copy.no.ref.struct(i8* %dst, i8* %src, i64 16), !AggType !0
  ret void
}
declare void @llvm.cj.copy.no.ref.struct(i8*, i8*, i64)
!0 = !{!"NotPresent"}

;--- as1-field.ll
%WithRef = type { i8 addrspace(1)*, i64 }
define void @reject_as1_field(i8* %dst, i8* %src) gc "cangjie" {
entry:
  call void @llvm.cj.copy.no.ref.struct(i8* %dst, i8* %src, i64 16), !AggType !0
  ret void
}
declare void @llvm.cj.copy.no.ref.struct(i8*, i8*, i64)
!0 = !{!"WithRef"}

;--- size-mismatch.ll
%Plain = type { i8*, i64 }
define void @reject_size_mismatch(i8* %dst, i8* %src) gc "cangjie" {
entry:
  call void @llvm.cj.copy.no.ref.struct(i8* %dst, i8* %src, i64 8), !AggType !0
  ret void
}
declare void @llvm.cj.copy.no.ref.struct(i8*, i8*, i64)
!0 = !{!"Plain"}

;--- dynamic-size.ll
%Plain = type { i8*, i64 }
define void @reject_dynamic_size(i8* %dst, i8* %src, i64 %size) gc "cangjie" {
entry:
  call void @llvm.cj.copy.no.ref.struct(i8* %dst, i8* %src, i64 %size), !AggType !0
  ret void
}
declare void @llvm.cj.copy.no.ref.struct(i8*, i8*, i64)
!0 = !{!"Plain"}
