; RUN: opt -passes=cj-typed-read-helper -S < %s | FileCheck %s

%RefPayload = type { i8 addrspace(1)* }
define void @reject_dynamic(i8 addrspace(1)* %src, i64 %n) gc "cangjie" {
entry:
  %dst.object = alloca %RefPayload, align 8
  %dst = bitcast %RefPayload* %dst.object to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst, i8 addrspace(1)* %src,
                                       i64 %n, i1 false)
  ret void
}

define void @reject_non_entry(i8 addrspace(1)* %src) gc "cangjie" {
entry:
  br label %body
body:
  %dst.object = alloca %RefPayload, align 8
  %dst = bitcast %RefPayload* %dst.object to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst, i8 addrspace(1)* %src,
                                       i64 8, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)

; CHECK-LABEL: define void @reject_dynamic
; CHECK: llvm.memcpy
; CHECK-LABEL: define void @reject_non_entry
; CHECK: llvm.memcpy
