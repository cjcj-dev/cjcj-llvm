; RUN: split-file %s %t
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-multi-index-source.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=MULTI,ABORT
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-selected-base-source.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=SELECT,ABORT

; XFAIL: *
; Baseline debt: product reports [silent-exit:*] and does not abort (same
; FileCheck emptiness on baseline 314a03f2516e1a0a22330285740b799be1e74da1).
; MULTI/SELECT FileCheck also requires ABORT text.

; MULTI: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [silent-exit:multi-index] [unknown-payload:report]
; MULTI-NEXT: call void @llvm.memcpy.p0i8.p1i8.i64
; MULTI: in function reject_typed_source_with_preceding_index
; SELECT: Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance. [silent-exit:selected-base] [unknown-payload:report]
; SELECT-NEXT: call void @llvm.memcpy.p0i8.p1i8.i64
; SELECT: in function reject_typed_source_with_selected_base
; ABORT: LLVM ERROR: Broken function found, compilation aborted
; ABORT: error: Aborted

;--- reject-multi-index-source.ll
%Plain8 = type { i64 }

define void @reject_typed_source_with_preceding_index(
    i8 addrspace(1)* %object) gc "cangjie" {
entry:
  %container = bitcast i8 addrspace(1)* %object to [2 x i8*] addrspace(1)*
  %payload.raw = getelementptr [2 x i8*], [2 x i8*] addrspace(1)* %container,
                               i32 0, i32 1
  %payload.typed = bitcast i8* addrspace(1)* %payload.raw to %Plain8 addrspace(1)*
  %src = bitcast %Plain8 addrspace(1)* %payload.typed to i8 addrspace(1)*
  %dst.object = alloca %Plain8, align 8
  %dst = bitcast %Plain8* %dst.object to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst, i8 addrspace(1)* %src,
                                       i64 8, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)

;--- reject-selected-base-source.ll
%Plain8 = type { i64 }

define void @reject_typed_source_with_selected_base(
    i1 %pick, i8 addrspace(1)* %a, i8 addrspace(1)* %b) gc "cangjie" {
entry:
  %object = select i1 %pick, i8 addrspace(1)* %a, i8 addrspace(1)* %b
  %carrier = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.raw = getelementptr i8*, i8* addrspace(1)* %carrier, i32 1
  %payload.typed = bitcast i8* addrspace(1)* %payload.raw to %Plain8 addrspace(1)*
  %src = bitcast %Plain8 addrspace(1)* %payload.typed to i8 addrspace(1)*
  %dst.object = alloca %Plain8, align 8
  %dst = bitcast %Plain8* %dst.object to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst, i8 addrspace(1)* %src,
                                       i64 8, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
