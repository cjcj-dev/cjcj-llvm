; RUN: cjir-capture --module-name=positive %s | FileCheck %s

target datalayout = "e-p:64:64:64-p1:64:64:64"

%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }
%ArrayLayout = type { i64, [0 x %Element] }
%Element = type { i8 addrspace(1)*, i64 }

@element.ti = global %TypeInfo zeroinitializer, !RelatedType !0

define void @overlapping_slot(i8* %src) gc "cangjie" {
entry:
  %root = call i8 addrspace(1)* @llvm.cj.malloc.array(i8* bitcast (%TypeInfo* @element.ti to i8*), i64 2, i64 16)
  %slot = getelementptr i8, i8 addrspace(1)* %root, i64 16
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %slot, i8* %src, i64 16, i1 false)
  ret void
}

; CHECK: CJIR_CAPTURE
; CHECK-SAME: "contains_gc_ptr_result":true
; CHECK-SAME: "gc_slot_positions":["16","32"]
; CHECK-SAME: "overlap":true
; CHECK-SAME: "src_complete_type":{"reason":"bare_i8_carrier","status":"unrecoverable"}

declare i8 addrspace(1)* @llvm.cj.malloc.array(i8*, i64, i64)
declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)

!0 = !{!"ArrayLayout"}
