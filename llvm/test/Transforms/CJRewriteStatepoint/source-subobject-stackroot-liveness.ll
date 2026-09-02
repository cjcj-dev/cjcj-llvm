; RUN: opt -passes='cj-ir-verifier,cj-rewrite-statepoint' -S < %s | FileCheck %s

target datalayout = "e-p:64:64-p1:64:64"

%Payload = type { i8 addrspace(1)*, i64, i8 addrspace(1)* }
%Outer = type { i64, %Payload }

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
declare void @safepoint()

; The verifier admission and statepoint registration share the same entry
; alloca surface.  Both reference fields are live after the safepoint, so the
; liveness pass combines them into the whole registered root.
; CHECK-LABEL: define i8 addrspace(1)* @live_destination
; CHECK: call token (...) @llvm.cj.gc.statepoint{{.*}}@safepoint{{.*}}[ "struct-live"(%Payload* %dst) ]
define i8 addrspace(1)* @live_destination(%Outer* %src.outer) gc "cangjie" {
entry:
  %dst = alloca %Payload, align 8
  %dst.i8 = bitcast %Payload* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 24, i1 false)
  %src.field = getelementptr inbounds %Outer, %Outer* %src.outer, i32 0, i32 1
  %src.i8 = bitcast %Payload* %src.field to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 24, i1 false)
  call void @safepoint()
  %first.slot = getelementptr inbounds %Payload, %Payload* %dst, i32 0, i32 0
  %last.slot = getelementptr inbounds %Payload, %Payload* %dst, i32 0, i32 2
  %first = load i8 addrspace(1)*, i8 addrspace(1)** %first.slot, align 8
  %last = load i8 addrspace(1)*, i8 addrspace(1)** %last.slot, align 8
  %pick = icmp eq i8 addrspace(1)* %first, null
  %result = select i1 %pick, i8 addrspace(1)* %last, i8 addrspace(1)* %first
  ret i8 addrspace(1)* %result
}

; Registration eligibility is not unconditional enumeration.  With no use
; after the safepoint, the destination is dead and struct-live stays absent.
; CHECK-LABEL: define void @dead_destination
; CHECK: call token (...) @llvm.cj.gc.statepoint{{.*}}@safepoint
; CHECK-NOT: "struct-live"(%Payload* %dst)
; CHECK: ret void
define void @dead_destination(%Outer* %src.outer) gc "cangjie" {
entry:
  %dst = alloca %Payload, align 8
  %dst.i8 = bitcast %Payload* %dst to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 24, i1 false)
  %src.field = getelementptr inbounds %Outer, %Outer* %src.outer, i32 0, i32 1
  %src.i8 = bitcast %Payload* %src.field to i8*
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 24, i1 false)
  call void @safepoint()
  ret void
}
