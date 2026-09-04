; RUN: split-file %s %t
; RUN: opt -passes=cj-ir-verifier < %t/allow-gcread-struct.ll -disable-output
; RUN: opt '-passes=default<O0>' --cangjie-pipeline -disable-output < %t/allow-gcread-struct.ll
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-ref.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=ABORT,REF
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-size.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=ABORT,SIZE
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-carrier.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=ABORT,CARRIER
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-bare-load.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=ABORT,BARE
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-call-linear.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=ABORT,STALE
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-call-diamond.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=ABORT,STALE
; RUN: not not opt -passes=cj-ir-verifier < %t/reject-call-loop.ll -disable-output 2>&1 | FileCheck %s -check-prefixes=ABORT,STALE
; RUN: opt -passes=cj-ir-verifier < %t/allow-no-call-diamond.ll -disable-output

;--- allow-gcread-struct.ll
%ArrayBase = type { i8 addrspace(1)*, i64 }
%Entry = type { i64, i64, i32, %Unit }
%Unit = type { i8 }
%Array = type { i8 addrspace(1)*, i64, i64 }
%"ArrayLayout.Entry" = type { %ArrayBase, [0 x %Entry] }

define void @allow_gcread_struct(i8 addrspace(1)* %base, i64 %idx) gc "cangjie" {
entry:
  %src = alloca %Entry, align 8
  %arr = alloca %Array, align 8
  %arr.bytes = bitcast %Array* %arr to i8*
  %base.array = bitcast i8 addrspace(1)* %base to %Array addrspace(1)*
  %arr.heap.bytes = bitcast %Array addrspace(1)* %base.array to i8 addrspace(1)*
  call void @llvm.cj.memset.p0i8(i8* %arr.bytes, i8 0, i64 24, i1 false)
  call void @llvm.cj.gcread.struct.i64(i8* %arr.bytes, i8 addrspace(1)* %base, i8 addrspace(1)* %arr.heap.bytes, i64 24), !AggType !0
  %data.gep = getelementptr inbounds %Array, %Array* %arr, i32 0, i32 0
  %data = load i8 addrspace(1)*, i8 addrspace(1)** %data.gep
  %carrier = bitcast i8 addrspace(1)* %data to i8* addrspace(1)*
  %payload = getelementptr i8*, i8* addrspace(1)* %carrier, i32 1
  %layout = bitcast i8* addrspace(1)* %payload to %"ArrayLayout.Entry" addrspace(1)*
  %elt = getelementptr inbounds %"ArrayLayout.Entry", %"ArrayLayout.Entry" addrspace(1)* %layout, i32 0, i32 1, i64 %idx
  %dst = bitcast %Entry addrspace(1)* %elt to i8 addrspace(1)*
  %src.bytes = bitcast %Entry* %src to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %dst, i8* %src.bytes, i64 24, i1 false)
  ret void
}

declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)
declare void @llvm.cj.gcread.struct.i64(i8*, i8 addrspace(1)*, i8 addrspace(1)*, i64)
declare void @llvm.cj.memset.p0i8(i8*, i8, i64, i1)
!0 = !{!"Array"}

;--- reject-ref.ll
%ArrayBase = type { i8 addrspace(1)*, i64 }
%Entry = type { i64, i8 addrspace(1)* }
%"ArrayLayout.Entry" = type { %ArrayBase, [0 x %Entry] }
define void @reject_ref(i8 addrspace(1)* %base, i64 %idx) gc "cangjie" {
entry:
  %src = alloca %Entry, align 8
  %layout = bitcast i8 addrspace(1)* %base to %"ArrayLayout.Entry" addrspace(1)*
  %elt = getelementptr inbounds %"ArrayLayout.Entry", %"ArrayLayout.Entry" addrspace(1)* %layout, i32 0, i32 1, i64 %idx
  %dst = bitcast %Entry addrspace(1)* %elt to i8 addrspace(1)*
  %src.bytes = bitcast %Entry* %src to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %dst, i8* %src.bytes, i64 16, i1 false)
  ret void
}
declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)
; REF: Bare memcpy/memmove of reference payload

;--- reject-size.ll
%ArrayBase = type { i8 addrspace(1)*, i64 }
%Entry = type { i64, i64, i32, %Unit }
%Unit = type { i8 }
%"ArrayLayout.Entry" = type { %ArrayBase, [0 x %Entry] }
define void @reject_size(i8 addrspace(1)* %base, i64 %idx) gc "cangjie" {
entry:
  %src = alloca %Entry, align 8
  %layout = bitcast i8 addrspace(1)* %base to %"ArrayLayout.Entry" addrspace(1)*
  %elt = getelementptr inbounds %"ArrayLayout.Entry", %"ArrayLayout.Entry" addrspace(1)* %layout, i32 0, i32 1, i64 %idx
  %dst = bitcast %Entry addrspace(1)* %elt to i8 addrspace(1)*
  %src.bytes = bitcast %Entry* %src to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %dst, i8* %src.bytes, i64 16, i1 false)
  ret void
}
declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)
; SIZE: Bare memcpy/memmove payload provenance is unknown

;--- reject-carrier.ll
%ArrayBase = type { i8 addrspace(1)*, i64 }
%Entry = type { i64, i64, i32, %Unit }
%Unit = type { i8 }
%"ArrayLayout.Entry" = type { %ArrayBase, [0 x %Entry] }
define void @reject_carrier(i8 addrspace(1)* %base, i64 %idx) gc "cangjie" {
entry:
  %src = alloca [24 x i8], align 1
  %layout = bitcast i8 addrspace(1)* %base to %"ArrayLayout.Entry" addrspace(1)*
  %elt = getelementptr inbounds %"ArrayLayout.Entry", %"ArrayLayout.Entry" addrspace(1)* %layout, i32 0, i32 1, i64 %idx
  %dst = bitcast %Entry addrspace(1)* %elt to i8 addrspace(1)*
  %src.bytes = bitcast [24 x i8]* %src to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %dst, i8* %src.bytes, i64 24, i1 false)
  ret void
}
declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)
; CARRIER: Bare memcpy/memmove payload provenance is unknown

;--- reject-bare-load.ll
%ArrayBase = type { i8 addrspace(1)*, i64 }
%Entry = type { i64, i64, i32, %Unit }
%Unit = type { i8 }
%Array = type { i8 addrspace(1)*, i64, i64 }
%"ArrayLayout.Entry" = type { %ArrayBase, [0 x %Entry] }
define void @reject_bare_load(i8 addrspace(1)* %base, i64 %idx) gc "cangjie" {
entry:
  %src = alloca %Entry, align 8
  %arr = alloca %Array, align 8
  %data.gep = getelementptr inbounds %Array, %Array* %arr, i32 0, i32 0
  %data = load i8 addrspace(1)*, i8 addrspace(1)** %data.gep
  %carrier = bitcast i8 addrspace(1)* %data to i8* addrspace(1)*
  %payload = getelementptr i8*, i8* addrspace(1)* %carrier, i32 1
  %layout = bitcast i8* addrspace(1)* %payload to %"ArrayLayout.Entry" addrspace(1)*
  %elt = getelementptr inbounds %"ArrayLayout.Entry", %"ArrayLayout.Entry" addrspace(1)* %layout, i32 0, i32 1, i64 %idx
  %dst = bitcast %Entry addrspace(1)* %elt to i8 addrspace(1)*
  %src.bytes = bitcast %Entry* %src to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %dst, i8* %src.bytes, i64 24, i1 false)
  ret void
}
declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)
; BARE: Bare memcpy/memmove payload provenance is unknown

;--- reject-call-linear.ll
%ArrayBase = type { i8 addrspace(1)*, i64 }
%Entry = type { i64, i64, i32, %Unit }
%Unit = type { i8 }
%Array = type { i8 addrspace(1)*, i64, i64 }
%"ArrayLayout.Entry" = type { %ArrayBase, [0 x %Entry] }
define void @reject_call_linear(i8 addrspace(1)* %base, i64 %idx) gc "cangjie" {
entry:
  %src = alloca %Entry, align 8
  %arr = alloca %Array, align 8
  %arr.bytes = bitcast %Array* %arr to i8*
  %base.array = bitcast i8 addrspace(1)* %base to %Array addrspace(1)*
  %arr.heap.bytes = bitcast %Array addrspace(1)* %base.array to i8 addrspace(1)*
  call void @llvm.cj.memset.p0i8(i8* %arr.bytes, i8 0, i64 24, i1 false)
  call void @llvm.cj.gcread.struct.i64(i8* %arr.bytes, i8 addrspace(1)* %base, i8 addrspace(1)* %arr.heap.bytes, i64 24), !AggType !0
  call void @unknown_may_gc()
  %data.gep = getelementptr inbounds %Array, %Array* %arr, i32 0, i32 0
  %data = load i8 addrspace(1)*, i8 addrspace(1)** %data.gep
  %carrier = bitcast i8 addrspace(1)* %data to i8* addrspace(1)*
  %payload = getelementptr i8*, i8* addrspace(1)* %carrier, i32 1
  %layout = bitcast i8* addrspace(1)* %payload to %"ArrayLayout.Entry" addrspace(1)*
  %elt = getelementptr inbounds %"ArrayLayout.Entry", %"ArrayLayout.Entry" addrspace(1)* %layout, i32 0, i32 1, i64 %idx
  %dst = bitcast %Entry addrspace(1)* %elt to i8 addrspace(1)*
  %src.bytes = bitcast %Entry* %src to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %dst, i8* %src.bytes, i64 24, i1 false)
  ret void
}
declare void @unknown_may_gc()
declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)
declare void @llvm.cj.gcread.struct.i64(i8*, i8 addrspace(1)*, i8 addrspace(1)*, i64)
declare void @llvm.cj.memset.p0i8(i8*, i8, i64, i1)
!0 = !{!"Array"}

;--- reject-call-diamond.ll
%ArrayBase = type { i8 addrspace(1)*, i64 }
%Entry = type { i64, i64, i32, %Unit }
%Unit = type { i8 }
%Array = type { i8 addrspace(1)*, i64, i64 }
%"ArrayLayout.Entry" = type { %ArrayBase, [0 x %Entry] }
define void @reject_call_diamond(i8 addrspace(1)* %base, i64 %idx, i1 %take.call) gc "cangjie" {
entry:
  %src = alloca %Entry, align 8
  %arr = alloca %Array, align 8
  %arr.bytes = bitcast %Array* %arr to i8*
  %base.array = bitcast i8 addrspace(1)* %base to %Array addrspace(1)*
  %arr.heap.bytes = bitcast %Array addrspace(1)* %base.array to i8 addrspace(1)*
  call void @llvm.cj.memset.p0i8(i8* %arr.bytes, i8 0, i64 24, i1 false)
  call void @llvm.cj.gcread.struct.i64(i8* %arr.bytes, i8 addrspace(1)* %base, i8 addrspace(1)* %arr.heap.bytes, i64 24), !AggType !0
  br i1 %take.call, label %with.call, label %without.call
with.call:
  call void @unknown_may_gc()
  br label %join
without.call:
  br label %join
join:
  %data.gep = getelementptr inbounds %Array, %Array* %arr, i32 0, i32 0
  %data = load i8 addrspace(1)*, i8 addrspace(1)** %data.gep
  %carrier = bitcast i8 addrspace(1)* %data to i8* addrspace(1)*
  %payload = getelementptr i8*, i8* addrspace(1)* %carrier, i32 1
  %layout = bitcast i8* addrspace(1)* %payload to %"ArrayLayout.Entry" addrspace(1)*
  %elt = getelementptr inbounds %"ArrayLayout.Entry", %"ArrayLayout.Entry" addrspace(1)* %layout, i32 0, i32 1, i64 %idx
  %dst = bitcast %Entry addrspace(1)* %elt to i8 addrspace(1)*
  %src.bytes = bitcast %Entry* %src to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %dst, i8* %src.bytes, i64 24, i1 false)
  ret void
}
declare void @unknown_may_gc()
declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)
declare void @llvm.cj.gcread.struct.i64(i8*, i8 addrspace(1)*, i8 addrspace(1)*, i64)
declare void @llvm.cj.memset.p0i8(i8*, i8, i64, i1)
!0 = !{!"Array"}

;--- reject-call-loop.ll
%ArrayBase = type { i8 addrspace(1)*, i64 }
%Entry = type { i64, i64, i32, %Unit }
%Unit = type { i8 }
%Array = type { i8 addrspace(1)*, i64, i64 }
%"ArrayLayout.Entry" = type { %ArrayBase, [0 x %Entry] }
define void @reject_call_loop(i8 addrspace(1)* %base, i64 %idx, i1 %again) gc "cangjie" {
entry:
  %src = alloca %Entry, align 8
  %arr = alloca %Array, align 8
  %arr.bytes = bitcast %Array* %arr to i8*
  %base.array = bitcast i8 addrspace(1)* %base to %Array addrspace(1)*
  %arr.heap.bytes = bitcast %Array addrspace(1)* %base.array to i8 addrspace(1)*
  call void @llvm.cj.memset.p0i8(i8* %arr.bytes, i8 0, i64 24, i1 false)
  call void @llvm.cj.gcread.struct.i64(i8* %arr.bytes, i8 addrspace(1)* %base, i8 addrspace(1)* %arr.heap.bytes, i64 24), !AggType !0
  br label %loop
loop:
  %data.gep = getelementptr inbounds %Array, %Array* %arr, i32 0, i32 0
  %data = load i8 addrspace(1)*, i8 addrspace(1)** %data.gep
  %carrier = bitcast i8 addrspace(1)* %data to i8* addrspace(1)*
  %payload = getelementptr i8*, i8* addrspace(1)* %carrier, i32 1
  %layout = bitcast i8* addrspace(1)* %payload to %"ArrayLayout.Entry" addrspace(1)*
  %elt = getelementptr inbounds %"ArrayLayout.Entry", %"ArrayLayout.Entry" addrspace(1)* %layout, i32 0, i32 1, i64 %idx
  %dst = bitcast %Entry addrspace(1)* %elt to i8 addrspace(1)*
  %src.bytes = bitcast %Entry* %src to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %dst, i8* %src.bytes, i64 24, i1 false)
  br i1 %again, label %backedge, label %exit
backedge:
  call void @unknown_may_gc()
  br label %loop
exit:
  ret void
}
declare void @unknown_may_gc()
declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)
declare void @llvm.cj.gcread.struct.i64(i8*, i8 addrspace(1)*, i8 addrspace(1)*, i64)
declare void @llvm.cj.memset.p0i8(i8*, i8, i64, i1)
!0 = !{!"Array"}

;--- allow-no-call-diamond.ll
%ArrayBase = type { i8 addrspace(1)*, i64 }
%Entry = type { i64, i64, i32, %Unit }
%Unit = type { i8 }
%Array = type { i8 addrspace(1)*, i64, i64 }
%"ArrayLayout.Entry" = type { %ArrayBase, [0 x %Entry] }
define void @allow_no_call_diamond(i8 addrspace(1)* %base, i64 %idx, i1 %take.left) gc "cangjie" {
entry:
  %src = alloca %Entry, align 8
  %arr = alloca %Array, align 8
  %arr.bytes = bitcast %Array* %arr to i8*
  %base.array = bitcast i8 addrspace(1)* %base to %Array addrspace(1)*
  %arr.heap.bytes = bitcast %Array addrspace(1)* %base.array to i8 addrspace(1)*
  call void @llvm.cj.memset.p0i8(i8* %arr.bytes, i8 0, i64 24, i1 false)
  call void @llvm.cj.gcread.struct.i64(i8* %arr.bytes, i8 addrspace(1)* %base, i8 addrspace(1)* %arr.heap.bytes, i64 24), !AggType !0
  br i1 %take.left, label %left, label %right
left:
  br label %join
right:
  br label %join
join:
  %data.gep = getelementptr inbounds %Array, %Array* %arr, i32 0, i32 0
  %data = load i8 addrspace(1)*, i8 addrspace(1)** %data.gep
  %carrier = bitcast i8 addrspace(1)* %data to i8* addrspace(1)*
  %payload = getelementptr i8*, i8* addrspace(1)* %carrier, i32 1
  %layout = bitcast i8* addrspace(1)* %payload to %"ArrayLayout.Entry" addrspace(1)*
  %elt = getelementptr inbounds %"ArrayLayout.Entry", %"ArrayLayout.Entry" addrspace(1)* %layout, i32 0, i32 1, i64 %idx
  %dst = bitcast %Entry addrspace(1)* %elt to i8 addrspace(1)*
  %src.bytes = bitcast %Entry* %src to i8*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %dst, i8* %src.bytes, i64 24, i1 false)
  ret void
}
declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)
declare void @llvm.cj.gcread.struct.i64(i8*, i8 addrspace(1)*, i8 addrspace(1)*, i64)
declare void @llvm.cj.memset.p0i8(i8*, i8, i64, i1)
!0 = !{!"Array"}

; STALE: Bare memcpy/memmove payload provenance is unknown

; ABORT: LLVM ERROR: Broken function found, compilation aborted
