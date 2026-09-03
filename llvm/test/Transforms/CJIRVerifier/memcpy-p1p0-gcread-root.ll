; RUN: split-file %s %t
; RUN: opt -passes=cj-ir-verifier < %t/allow-gcread-root.ll -disable-output
; RUN: opt -passes=cj-ir-verifier < %t/allow-this-debug-reload.ll -disable-output
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-src-has-ref.ll -disable-output 2>&1 | FileCheck %s --check-prefix=REFSRC
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-dest-ref-slot.ll -disable-output 2>&1 | FileCheck %s --check-prefix=REFSLOT
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-bare-as1-load.ll -disable-output 2>&1 | FileCheck %s --check-prefix=BARELOAD
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-size-mismatch.ll -disable-output 2>&1 | FileCheck %s --check-prefix=SIZE
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-call-between-store-reload.ll -disable-output 2>&1 | FileCheck %s --check-prefix=SAFEBETWEEN

; REFSRC: Bare memcpy/memmove of reference payload
; REFSRC: in function reject_src_has_ref
; REFSLOT: Bare memcpy/memmove
; REFSLOT: in function reject_dest_ref_slot
; BARELOAD: Bare memcpy/memmove payload provenance is unknown
; BARELOAD: in function reject_bare_as1_load
; SIZE: Bare memcpy/memmove payload provenance is unknown
; SIZE: in function reject_size_mismatch
; SAFEBETWEEN: spill-slot reload across a possible GC safepoint
; SAFEBETWEEN: in function reject_call_between_store_reload

;--- allow-gcread-root.ll
%"enum.std.core:Option<Float64>" = type { i1, double }
%"ObjLayout.std.random:Random" = type { i8 addrspace(1)*, i64, %"enum.std.core:Option<Float64>" }

define void @allow_gcread_root_option_field(i8 addrspace(1)* %holder) gc "cangjie" {
entry:
  %holder.hdr = bitcast i8 addrspace(1)* %holder to i8* addrspace(1)*
  %holder.payload = getelementptr i8*, i8* addrspace(1)* %holder.hdr, i32 1
  %holder.obj = bitcast i8* addrspace(1)* %holder.payload to %"ObjLayout.std.random:Random" addrspace(1)*
  %slot = getelementptr inbounds %"ObjLayout.std.random:Random", %"ObjLayout.std.random:Random" addrspace(1)* %holder.obj, i32 0, i32 0
  %this = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %holder, i8 addrspace(1)* addrspace(1)* %slot)
  %hdr = bitcast i8 addrspace(1)* %this to i8* addrspace(1)*
  %payload = getelementptr i8*, i8* addrspace(1)* %hdr, i32 1
  %obj = bitcast i8* addrspace(1)* %payload to %"ObjLayout.std.random:Random" addrspace(1)*
  %field = getelementptr inbounds %"ObjLayout.std.random:Random", %"ObjLayout.std.random:Random" addrspace(1)* %obj, i32 0, i32 2
  %dst = bitcast %"enum.std.core:Option<Float64>" addrspace(1)* %field to i8 addrspace(1)*
  %src.a = alloca %"enum.std.core:Option<Float64>", align 8
  %src = bitcast %"enum.std.core:Option<Float64>"* %src.a to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 8 %dst, i8* align 8 %src, i64 16, i1 false)
  ret void
}

declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)

;--- allow-this-debug-reload.ll
%"enum.std.core:Option<Float64>" = type { i1, double }
%"ObjLayout.std.random:Random" = type { i8 addrspace(1)*, i64, %"enum.std.core:Option<Float64>" }

define void @allow_this_debug_reload_option_field(i8 addrspace(1)* %this) gc "cangjie" {
entry:
  %this.debug = alloca i8 addrspace(1)*, align 8
  store i8 addrspace(1)* %this, i8 addrspace(1)** %this.debug, align 8
  %loaded = load i8 addrspace(1)*, i8 addrspace(1)** %this.debug, align 8
  %hdr = bitcast i8 addrspace(1)* %loaded to i8* addrspace(1)*
  %payload = getelementptr i8*, i8* addrspace(1)* %hdr, i32 1
  %obj = bitcast i8* addrspace(1)* %payload to %"ObjLayout.std.random:Random" addrspace(1)*
  %field = getelementptr inbounds %"ObjLayout.std.random:Random", %"ObjLayout.std.random:Random" addrspace(1)* %obj, i32 0, i32 2
  %dst = bitcast %"enum.std.core:Option<Float64>" addrspace(1)* %field to i8 addrspace(1)*
  %src.a = alloca %"enum.std.core:Option<Float64>", align 8
  %src = bitcast %"enum.std.core:Option<Float64>"* %src.a to i8*
  ; Mirror gaussian: a mem intrinsic between the store and the reload cannot
  ; be a GC safepoint, so it does not invalidate the spill slot.
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 8 %dst, i8* align 8 %src, i64 16, i1 false)
  %reloaded = load i8 addrspace(1)*, i8 addrspace(1)** %this.debug, align 8
  %hdr2 = bitcast i8 addrspace(1)* %reloaded to i8* addrspace(1)*
  %payload2 = getelementptr i8*, i8* addrspace(1)* %hdr2, i32 1
  %obj2 = bitcast i8* addrspace(1)* %payload2 to %"ObjLayout.std.random:Random" addrspace(1)*
  %field2 = getelementptr inbounds %"ObjLayout.std.random:Random", %"ObjLayout.std.random:Random" addrspace(1)* %obj2, i32 0, i32 2
  %dst2 = bitcast %"enum.std.core:Option<Float64>" addrspace(1)* %field2 to i8 addrspace(1)*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 8 %dst2, i8* align 8 %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)

;--- reject-src-has-ref.ll
%OptionRef = type { i1, i8 addrspace(1)* }
%ObjLayout = type { i8 addrspace(1)*, i64, %OptionRef }

define void @reject_src_has_ref(i8 addrspace(1)* %holder) gc "cangjie" {
entry:
  %holder.hdr = bitcast i8 addrspace(1)* %holder to i8* addrspace(1)*
  %holder.payload = getelementptr i8*, i8* addrspace(1)* %holder.hdr, i32 1
  %holder.obj = bitcast i8* addrspace(1)* %holder.payload to %ObjLayout addrspace(1)*
  %slot = getelementptr inbounds %ObjLayout, %ObjLayout addrspace(1)* %holder.obj, i32 0, i32 0
  %this = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %holder, i8 addrspace(1)* addrspace(1)* %slot)
  %hdr = bitcast i8 addrspace(1)* %this to i8* addrspace(1)*
  %payload = getelementptr i8*, i8* addrspace(1)* %hdr, i32 1
  %obj = bitcast i8* addrspace(1)* %payload to %ObjLayout addrspace(1)*
  %field = getelementptr inbounds %ObjLayout, %ObjLayout addrspace(1)* %obj, i32 0, i32 2
  %dst = bitcast %OptionRef addrspace(1)* %field to i8 addrspace(1)*
  %src.a = alloca %OptionRef, align 8
  %src = bitcast %OptionRef* %src.a to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 8 %dst, i8* align 8 %src, i64 16, i1 false)
  ret void
}

declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)

;--- reject-dest-ref-slot.ll
%"enum.std.core:Option<Float64>" = type { i1, double }
%ObjLayout = type { i8 addrspace(1)*, i8 addrspace(1)* }

define void @reject_dest_ref_slot(i8 addrspace(1)* %holder) gc "cangjie" {
entry:
  %holder.hdr = bitcast i8 addrspace(1)* %holder to i8* addrspace(1)*
  %holder.payload = getelementptr i8*, i8* addrspace(1)* %holder.hdr, i32 1
  %holder.obj = bitcast i8* addrspace(1)* %holder.payload to %ObjLayout addrspace(1)*
  %slot = getelementptr inbounds %ObjLayout, %ObjLayout addrspace(1)* %holder.obj, i32 0, i32 0
  %this = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %holder, i8 addrspace(1)* addrspace(1)* %slot)
  %hdr = bitcast i8 addrspace(1)* %this to i8* addrspace(1)*
  %payload = getelementptr i8*, i8* addrspace(1)* %hdr, i32 1
  %obj = bitcast i8* addrspace(1)* %payload to %ObjLayout addrspace(1)*
  %field = getelementptr inbounds %ObjLayout, %ObjLayout addrspace(1)* %obj, i32 0, i32 1
  %dst = bitcast i8 addrspace(1)* addrspace(1)* %field to i8 addrspace(1)*
  %src.a = alloca %"enum.std.core:Option<Float64>", align 8
  %src = bitcast %"enum.std.core:Option<Float64>"* %src.a to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 8 %dst, i8* align 8 %src, i64 16, i1 false)
  ret void
}

declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)

;--- reject-bare-as1-load.ll
%"enum.std.core:Option<Float64>" = type { i1, double }
%"ObjLayout.std.random:Random" = type { i8 addrspace(1)*, i64, %"enum.std.core:Option<Float64>" }

define void @reject_bare_as1_load(i8 addrspace(1)* addrspace(1)* %heap.slot) gc "cangjie" {
entry:
  %this = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %heap.slot, align 8
  %hdr = bitcast i8 addrspace(1)* %this to i8* addrspace(1)*
  %payload = getelementptr i8*, i8* addrspace(1)* %hdr, i32 1
  %obj = bitcast i8* addrspace(1)* %payload to %"ObjLayout.std.random:Random" addrspace(1)*
  %field = getelementptr inbounds %"ObjLayout.std.random:Random", %"ObjLayout.std.random:Random" addrspace(1)* %obj, i32 0, i32 2
  %dst = bitcast %"enum.std.core:Option<Float64>" addrspace(1)* %field to i8 addrspace(1)*
  %src.a = alloca %"enum.std.core:Option<Float64>", align 8
  %src = bitcast %"enum.std.core:Option<Float64>"* %src.a to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 8 %dst, i8* align 8 %src, i64 16, i1 false)
  ret void
}

declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)

;--- reject-size-mismatch.ll
%"enum.std.core:Option<Float64>" = type { i1, double }
%"ObjLayout.std.random:Random" = type { i8 addrspace(1)*, i64, %"enum.std.core:Option<Float64>" }

define void @reject_size_mismatch(i8 addrspace(1)* %holder) gc "cangjie" {
entry:
  %holder.hdr = bitcast i8 addrspace(1)* %holder to i8* addrspace(1)*
  %holder.payload = getelementptr i8*, i8* addrspace(1)* %holder.hdr, i32 1
  %holder.obj = bitcast i8* addrspace(1)* %holder.payload to %"ObjLayout.std.random:Random" addrspace(1)*
  %slot = getelementptr inbounds %"ObjLayout.std.random:Random", %"ObjLayout.std.random:Random" addrspace(1)* %holder.obj, i32 0, i32 0
  %this = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %holder, i8 addrspace(1)* addrspace(1)* %slot)
  %hdr = bitcast i8 addrspace(1)* %this to i8* addrspace(1)*
  %payload = getelementptr i8*, i8* addrspace(1)* %hdr, i32 1
  %obj = bitcast i8* addrspace(1)* %payload to %"ObjLayout.std.random:Random" addrspace(1)*
  %field = getelementptr inbounds %"ObjLayout.std.random:Random", %"ObjLayout.std.random:Random" addrspace(1)* %obj, i32 0, i32 2
  %dst = bitcast %"enum.std.core:Option<Float64>" addrspace(1)* %field to i8 addrspace(1)*
  %src.a = alloca %"enum.std.core:Option<Float64>", align 8
  %src = bitcast %"enum.std.core:Option<Float64>"* %src.a to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* align 8 %dst, i8* align 8 %src, i64 8, i1 false)
  ret void
}

declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)

;--- reject-call-between-store-reload.ll
%"enum.std.core:Option<Float64>" = type { i1, double }
%"ObjLayout.std.random:Random" = type { i8 addrspace(1)*, i64, %"enum.std.core:Option<Float64>" }

; A safepoint-capable call between the store and the reload may relocate the
; object; the spill slot keeps the pre-move address, so the reloaded pointer
; is no longer the canonical root and must stay rejected.
define void @reject_call_between_store_reload(i8 addrspace(1)* %this) gc "cangjie" {
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
