; RUN: split-file %s %t
; RUN: opt '-passes=default<O0>' --cangjie-pipeline -disable-output < %t/allow-this-debug-across-call.ll
; RUN: opt '-passes=default<O0>' --cangjie-pipeline -disable-output < %t/reject-unpromotable-across-call.ll 2>&1 | FileCheck %s --check-prefix=UNPROMOTE
; RUN: not not opt '-passes=default<O0>' --cangjie-pipeline -disable-output < %t/reject-src-has-ref.ll 2>&1 | FileCheck %s --check-prefix=REFSRC
; RUN: opt '-passes=default<O0>' --cangjie-pipeline -disable-output < %t/reject-dest-ref-slot.ll 2>&1 | FileCheck %s --check-prefix=REFSLOT
; RUN: opt -passes=cj-ir-verifier -disable-output < %t/allow-this-debug-across-call.ll 2>&1 | FileCheck %s --check-prefix=NOPROMOTE

; UNPROMOTE: Bare memcpy/memmove payload provenance is unknown
; REFSRC: Bare memcpy/memmove of reference payload
; REFSRC: in function reject_src_has_ref
; REFSLOT: Bare memcpy/memmove payload provenance is unknown
; NOPROMOTE: spill-slot reload across a possible GC safepoint

;--- allow-this-debug-across-call.ll
%"enum.std.core:Option<Float64>" = type { i1, double }
%"ObjLayout.std.random:Random" = type { i8 addrspace(1)*, i64, %"enum.std.core:Option<Float64>" }

; Gaussian second memcpy: %this.debug spill, a call, then reload as dest root
; of a p1<-p0 no-ref memcpy.  Pipeline mem2reg lifts the slot to SSA %this.
define void @allow_this_debug_across_call(i8 addrspace(1)* %this) gc "cangjie" {
entry:
  %this.debug = alloca i8 addrspace(1)*, align 8
  store i8 addrspace(1)* %this, i8 addrspace(1)** %this.debug, align 8
  call void @some_call()
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

declare void @some_call()
declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)

;--- reject-unpromotable-across-call.ll
%"enum.std.core:Option<Float64>" = type { i1, double }
%"ObjLayout.std.random:Random" = type { i8 addrspace(1)*, i64, %"enum.std.core:Option<Float64>" }

; Same spill shape, but the slot has a bitcast user so mem2reg cannot promote.
; The call between store and reload still rejects.
define void @reject_unpromotable_across_call(i8 addrspace(1)* %this) gc "cangjie" {
entry:
  %this.debug = alloca i8 addrspace(1)*, align 8
  %slot.i8 = bitcast i8 addrspace(1)** %this.debug to i8*
  store i8 addrspace(1)* %this, i8 addrspace(1)** %this.debug, align 8
  call void @escape_slot(i8* %slot.i8)
  call void @some_call()
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

declare void @some_call()
declare void @escape_slot(i8*)
declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)

;--- reject-src-has-ref.ll
%OptionRef = type { i1, i8 addrspace(1)* }
%ObjLayout = type { i8 addrspace(1)*, i64, %OptionRef }

define void @reject_src_has_ref(i8 addrspace(1)* %this) gc "cangjie" {
entry:
  %this.debug = alloca i8 addrspace(1)*, align 8
  store i8 addrspace(1)* %this, i8 addrspace(1)** %this.debug, align 8
  call void @some_call()
  %reloaded = load i8 addrspace(1)*, i8 addrspace(1)** %this.debug, align 8
  %hdr = bitcast i8 addrspace(1)* %reloaded to i8* addrspace(1)*
  %payload = getelementptr i8*, i8* addrspace(1)* %hdr, i32 1
  %obj = bitcast i8* addrspace(1)* %payload to %ObjLayout addrspace(1)*
  %field = getelementptr inbounds %ObjLayout, %ObjLayout addrspace(1)* %obj, i32 0, i32 2
  %dst = bitcast %OptionRef addrspace(1)* %field to i8 addrspace(1)*
  %src.a = alloca %OptionRef, align 8
  %src = bitcast %OptionRef* %src.a to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 8 %dst, i8* align 8 %src, i64 16, i1 false)
  ret void
}

declare void @some_call()
declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)

;--- reject-dest-ref-slot.ll
%"enum.std.core:Option<Float64>" = type { i1, double }
%ObjLayout = type { i8 addrspace(1)*, i8 addrspace(1)* }

define void @reject_dest_ref_slot(i8 addrspace(1)* %this) gc "cangjie" {
entry:
  %this.debug = alloca i8 addrspace(1)*, align 8
  store i8 addrspace(1)* %this, i8 addrspace(1)** %this.debug, align 8
  call void @some_call()
  %reloaded = load i8 addrspace(1)*, i8 addrspace(1)** %this.debug, align 8
  %hdr = bitcast i8 addrspace(1)* %reloaded to i8* addrspace(1)*
  %payload = getelementptr i8*, i8* addrspace(1)* %hdr, i32 1
  %obj = bitcast i8* addrspace(1)* %payload to %ObjLayout addrspace(1)*
  %field = getelementptr inbounds %ObjLayout, %ObjLayout addrspace(1)* %obj, i32 0, i32 1
  %dst = bitcast i8 addrspace(1)* addrspace(1)* %field to i8 addrspace(1)*
  %src.a = alloca %"enum.std.core:Option<Float64>", align 8
  %src = bitcast %"enum.std.core:Option<Float64>"* %src.a to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 8 %dst, i8* align 8 %src, i64 16, i1 false)
  ret void
}

declare void @some_call()
declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)
