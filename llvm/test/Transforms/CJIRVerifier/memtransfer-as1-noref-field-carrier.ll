; RUN: split-file %s %t
; RUN: opt -passes=cj-ir-verifier < %t/allow-gcread-position.ll -S | FileCheck %s --check-prefix=ALLOW
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-as1-field.ll -disable-output 2>&1 | FileCheck %s --check-prefix=HASREF
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-i8-payload.ll -disable-output 2>&1 | FileCheck %s --check-prefix=I8PAY
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-size-mismatch.ll -disable-output 2>&1 | FileCheck %s --check-prefix=SIZE
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-non-entry-alloca.ll -disable-output 2>&1 | FileCheck %s --check-prefix=DST

; ALLOW: call void @llvm.memcpy.p0i8.p1i8.i64
; HASREF: Bare memcpy/memmove of reference payload
; I8PAY: Bare memcpy/memmove payload provenance is unknown
; SIZE: Bare memcpy/memmove payload provenance is unknown
; DST: Bare memcpy/memmove payload provenance is unknown

;--- allow-gcread-position.ll
%Position = type { i32, i32, i32 }
%ObjLayout.Node = type { i8 addrspace(1)*, %Position }

define void @allow_gcread_position_field() gc "cangjie" {
entry:
  %obj = call i8 addrspace(1)* @llvm_cj_gcread_ref_sim()
  %layout = bitcast i8 addrspace(1)* %obj to %ObjLayout.Node addrspace(1)*
  %field = getelementptr inbounds %ObjLayout.Node, %ObjLayout.Node addrspace(1)* %layout, i32 0, i32 1
  %src = bitcast %Position addrspace(1)* %field to i8 addrspace(1)*
  %dst = alloca %Position, align 4
  %dst.b = bitcast %Position* %dst to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst.b, i8 addrspace(1)* %src, i64 12, i1 false)
  ret void
}

declare i8 addrspace(1)* @llvm_cj_gcread_ref_sim()
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)

;--- reject-as1-field.ll
%HasRef = type { i32, i8 addrspace(1)* }
%ObjLayout.Node = type { i8 addrspace(1)*, %HasRef }

define void @reject_pointee_contains_as1() gc "cangjie" {
entry:
  %obj = call i8 addrspace(1)* @llvm_cj_gcread_ref_sim()
  %layout = bitcast i8 addrspace(1)* %obj to %ObjLayout.Node addrspace(1)*
  %field = getelementptr inbounds %ObjLayout.Node, %ObjLayout.Node addrspace(1)* %layout, i32 0, i32 1
  %src = bitcast %HasRef addrspace(1)* %field to i8 addrspace(1)*
  %dst = alloca %HasRef, align 8
  %dst.b = bitcast %HasRef* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.b, i8 0, i64 16, i1 false)
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst.b, i8 addrspace(1)* %src, i64 16, i1 false)
  ret void
}

declare i8 addrspace(1)* @llvm_cj_gcread_ref_sim()
declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)

;--- reject-i8-payload.ll
define void @reject_erased_i8_payload(i8 addrspace(1)* %src) gc "cangjie" {
entry:
  %dst = alloca [12 x i8], align 1
  %dst.b = bitcast [12 x i8]* %dst to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst.b, i8 addrspace(1)* %src, i64 12, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)

;--- reject-size-mismatch.ll
%Position = type { i32, i32, i32 }

define void @reject_size_not_pointee() gc "cangjie" {
entry:
  %obj = call i8 addrspace(1)* @llvm_cj_gcread_ref_sim()
  %typed = bitcast i8 addrspace(1)* %obj to %Position addrspace(1)*
  %src = bitcast %Position addrspace(1)* %typed to i8 addrspace(1)*
  %dst = alloca %Position, align 4
  %dst.b = bitcast %Position* %dst to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst.b, i8 addrspace(1)* %src, i64 8, i1 false)
  ret void
}

declare i8 addrspace(1)* @llvm_cj_gcread_ref_sim()
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)

;--- reject-non-entry-alloca.ll
%Position = type { i32, i32, i32 }

define void @reject_dst_not_entry_alloca(i1 %c) gc "cangjie" {
entry:
  br i1 %c, label %later, label %end
later:
  %obj = call i8 addrspace(1)* @llvm_cj_gcread_ref_sim()
  %typed = bitcast i8 addrspace(1)* %obj to %Position addrspace(1)*
  %src = bitcast %Position addrspace(1)* %typed to i8 addrspace(1)*
  %dst = alloca %Position, align 4
  %dst.b = bitcast %Position* %dst to i8*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %dst.b, i8 addrspace(1)* %src, i64 12, i1 false)
  br label %end
end:
  ret void
}

declare i8 addrspace(1)* @llvm_cj_gcread_ref_sim()
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
