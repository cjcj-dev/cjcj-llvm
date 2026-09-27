; RUN: opt -passes=cj-ir-verifier < %s -disable-output 2>&1 | FileCheck %s
; CHECK: spill-slot reload across a possible GC safepoint
; CHECK: in function reject_call_between_store_reload

%"enum.std.core:Option<Float64>" = type { i1, double }
%"ObjLayout.std.random:Random" = type { i8 addrspace(1)*, i64, %"enum.std.core:Option<Float64>" }

; A safepoint-capable call between the store and the reload may relocate the
; object; the spill slot keeps the pre-move address, so the reloaded pointer
; is no longer the canonical root and must stay rejected.
define void @reject_call_between_store_reload(i8 addrspace(1)* %this) gc "cangjie" {
entry:
  %this.debug = alloca i8 addrspace(1)*, align 8
  store i8 addrspace(1)* %this, i8 addrspace(1)** %this.debug, align 8
  %raw = call i8* @llvm.cj.acquire.rawdata(i8 addrspace(1)* %this, i8* null)
  %reloaded = load i8 addrspace(1)*, i8 addrspace(1)** %this.debug, align 8
  %hdr = bitcast i8 addrspace(1)* %reloaded to i8* addrspace(1)*
  %payload = getelementptr i8*, i8* addrspace(1)* %hdr, i32 1
  %obj = bitcast i8* addrspace(1)* %payload to %"ObjLayout.std.random:Random" addrspace(1)*
  %field = getelementptr inbounds %"ObjLayout.std.random:Random", %"ObjLayout.std.random:Random" addrspace(1)* %obj, i32 0, i32 2
  %dst = bitcast %"enum.std.core:Option<Float64>" addrspace(1)* %field to i8 addrspace(1)*
  %src.a = alloca %"enum.std.core:Option<Float64>", align 8
  %src = bitcast %"enum.std.core:Option<Float64>"* %src.a to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 8 %dst, i8* align 8 %src, i64 16, i1 false)
  ret void
}

declare i8* @llvm.cj.acquire.rawdata(i8 addrspace(1)*, i8*)
declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)
