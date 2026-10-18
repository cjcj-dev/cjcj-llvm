; RUN: split-file %s %t
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/ref.ll 2>&1 | FileCheck %s --check-prefix=REF
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/ref-memmove.ll 2>&1 | FileCheck %s --check-prefix=REF
; RUN: opt -passes=cj-ir-verifier -disable-output %t/plain.ll
; RUN: opt -passes=cj-ir-verifier -disable-output %t/unsigned-allocation-size.ll
; RUN: opt -passes=cj-ir-verifier -disable-output %t/partial-plain.ll
; RUN: opt -passes=cj-ir-verifier -disable-output %t/partial-plain-memmove.ll
; RUN: opt -passes=cj-ir-verifier -disable-output %t/helper.ll
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/legacy-ref-carrier.ll 2>&1 | FileCheck %s --check-prefix=REF
; RUN: opt -passes=cj-ir-verifier -disable-output %t/before-ref.ll
; RUN: opt -passes=cj-ir-verifier -disable-output %t/after-ref.ll
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/half-ref.ll 2>&1 | FileCheck %s --check-prefix=REF
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/nested-ref.ll 2>&1 | FileCheck %s --check-prefix=REF
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/header.ll 2>&1 | FileCheck %s --check-prefix=INVALID
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/negative.ll 2>&1 | FileCheck %s --check-prefix=INVALID
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/out-of-bounds.ll 2>&1 | FileCheck %s --check-prefix=INVALID
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/allocation-size.ll 2>&1 | FileCheck %s --check-prefix=INVALID
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/multiply-overflow.ll 2>&1 | FileCheck %s --check-prefix=INVALID
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/sum-overflow.ll 2>&1 | FileCheck %s --check-prefix=INVALID
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/wide-index.ll 2>&1 | FileCheck %s --check-prefix=INVALID
; RUN: opt -passes=cj-ir-verifier -disable-output %t/dynamic-offset.ll
; RUN: opt -passes=cj-ir-verifier -disable-output %t/dynamic-allocation.ll
; RUN: opt -passes=cj-ir-verifier -disable-output %t/unknown-layout.ll
; RUN: opt -passes=cj-ir-verifier -disable-output %t/reference-vector-unsupported.ll
; RUN: opt -passes=no-op-module %t/ref.ll -o %t/ref.bc
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %t/ref.bc 2>&1 | FileCheck %s --check-prefix=REF
; RUN: not --crash opt -passes='default<O0>' --cangjie-pipeline --only-verify-out %t/ref.bc -o %t/ref.out.bc 2>&1 | FileCheck %s --check-prefix=REF
; RUN: rm -f %t/report.tsv
; RUN: env CJ_IR_VERIFIER_MODE=report CJ_IR_VERIFIER_REPORT=%t/report.tsv opt -passes=cj-ir-verifier -disable-output %t/ref.bc
; RUN: cat %t/report.tsv | count 2
; RUN: FileCheck %s --check-prefix=REPORT < %t/report.tsv
; RUN: rm -f %t/control.tsv
; RUN: env CJ_IR_VERIFIER_MODE=report CJ_IR_VERIFIER_REPORT=%t/control.tsv opt -passes=cj-ir-verifier -disable-output %t/partial-plain.ll
; RUN: cat %t/control.tsv | count 1
; RUN: FileCheck %s --check-prefix=HEADER < %t/control.tsv
; RUN: opt -passes=cj-ir-verifier,cj-typed-read-helper -S %t/helper.ll | FileCheck %s --check-prefix=HELPER
; RUN: opt -passes='default<O0>' --cangjie-pipeline -S %t/helper.ll | FileCheck %s --check-prefix=HELPERPIPE
;
; A Plain carrier is not independent evidence against a known allocation TI.
; TI uses the retained official 1005 declaration (52-frontend@cjcj.bc).
; The external Layout anchor keeps RelatedType resolvable through bitcode.
; All copies retain a complete, same-size Plain alloca and typed AS1 carrier,
; so the new field-carrier consumer must check the allocation's payload range.
; Offsets are object-relative: 8 is the first payload byte on this fixed ABI.
; Dynamic/unrecoverable provenance and reference vectors retain old policy;
; their green results do not claim a reference-free payload proof.
;
; REF: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; REF: call void @llvm.mem{{cpy|move}}.p0i8.p1i8.i64
; REF: in function target
; INVALID: Bare memcpy/memmove has an invalid known allocation payload range or size.
; INVALID: call void @llvm.memcpy.p0i8.p1i8.i64
; INVALID: in function target
; REPORT: module{{[[:space:]]}}function{{[[:space:]]}}rule
; REPORT-NEXT: {{.*}}target{{[[:space:]]}}Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.{{[[:space:]]}}memcpy{{[[:space:]]}}0{{[[:space:]]}}1{{[[:space:]]}}16
; REPORT-NOT: unknown-payload
; HEADER: module{{[[:space:]]}}function{{[[:space:]]}}rule{{[[:space:]]}}instruction{{[[:space:]]}}dest_as{{[[:space:]]}}src_as{{[[:space:]]}}length{{[[:space:]]}}dest_root{{[[:space:]]}}src_root{{[[:space:]]}}source_type
; HELPER: call void @llvm.cj.gcread.struct.i64
; HELPER-NOT: call void @llvm.memcpy
; HELPERPIPE: call i8 addrspace(1)* @llvm.cj.gcread.ref

;--- ref.ll
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, %ExtensionDef**, i8*, i8* }
%BitMap = type { i32, [0 x i8] }
%ExtensionDef = type { i32, i8, i8, i16, i8*, i8*, i8*, i8* }
%Plain16 = type { i64, i64 }
%Plain8 = type { i64 }
%OtherRef = type { i64, i8 addrspace(1)* }
%Layout = type { i64, i8 addrspace(1)* }
@layout.anchor = external global %Layout
@layout.ti = external global %TypeInfo, !RelatedType !0

define void @target(i64 %offset, i32 %allocation) gc "cangjie" {
entry:
  %dst = alloca %Plain16, align 8
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* bitcast (%TypeInfo* @layout.ti to i8*), i32 16)
  %carrier = bitcast i8 addrspace(1)* %obj to i8* addrspace(1)*
  %header = getelementptr i8*, i8* addrspace(1)* %carrier, i32 1
  %payload = bitcast i8* addrspace(1)* %header to i8 addrspace(1)*
  %typed = bitcast i8 addrspace(1)* %payload to %Plain16 addrspace(1)*
  %d = bitcast %Plain16* %dst to i8*
  %s = bitcast %Plain16 addrspace(1)* %typed to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* align 8 %d, i8 addrspace(1)* align 1 %s, i64 16, i1 false)
  call void @use(i8* %d)
  ret void
}
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
declare void @use(i8*)
!0 = !{!"Layout"}

;--- ref-memmove.ll
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, %ExtensionDef**, i8*, i8* }
%BitMap = type { i32, [0 x i8] }
%ExtensionDef = type { i32, i8, i8, i16, i8*, i8*, i8*, i8* }
%Plain16 = type { i64, i64 }
%Plain8 = type { i64 }
%OtherRef = type { i64, i8 addrspace(1)* }
%Layout = type { i64, i8 addrspace(1)* }
@layout.anchor = external global %Layout
@layout.ti = external global %TypeInfo, !RelatedType !0

define void @target(i64 %offset, i32 %allocation) gc "cangjie" {
entry:
  %dst = alloca %Plain16, align 8
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* bitcast (%TypeInfo* @layout.ti to i8*), i32 16)
  %payload = getelementptr i8, i8 addrspace(1)* %obj, i64 8
  %typed = bitcast i8 addrspace(1)* %payload to %Plain16 addrspace(1)*
  %d = bitcast %Plain16* %dst to i8*
  %s = bitcast %Plain16 addrspace(1)* %typed to i8 addrspace(1)*
  call void @llvm.memmove.p0i8.p1i8.i64(i8* align 8 %d, i8 addrspace(1)* align 1 %s, i64 16, i1 false)
  call void @use(i8* %d)
  ret void
}
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare void @llvm.memmove.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
declare void @use(i8*)
!0 = !{!"Layout"}

;--- plain.ll
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, %ExtensionDef**, i8*, i8* }
%BitMap = type { i32, [0 x i8] }
%ExtensionDef = type { i32, i8, i8, i16, i8*, i8*, i8*, i8* }
%Plain16 = type { i64, i64 }
%Plain8 = type { i64 }
%OtherRef = type { i64, i8 addrspace(1)* }
%Layout = type { i64, i64 }
@layout.anchor = external global %Layout
@layout.ti = external global %TypeInfo, !RelatedType !0

define void @target(i64 %offset, i32 %allocation) gc "cangjie" {
entry:
  %dst = alloca %Plain16, align 8
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* bitcast (%TypeInfo* @layout.ti to i8*), i32 16)
  %payload = getelementptr i8, i8 addrspace(1)* %obj, i64 8
  %typed = bitcast i8 addrspace(1)* %payload to %Plain16 addrspace(1)*
  %d = bitcast %Plain16* %dst to i8*
  %s = bitcast %Plain16 addrspace(1)* %typed to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* align 8 %d, i8 addrspace(1)* align 1 %s, i64 16, i1 false)
  call void @use(i8* %d)
  ret void
}
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
declare void @use(i8*)
!0 = !{!"Layout"}

;--- unsigned-allocation-size.ll
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, %ExtensionDef**, i8*, i8* }
%BitMap = type { i32, [0 x i8] }
%ExtensionDef = type { i32, i8, i8, i16, i8*, i8*, i8*, i8* }
%Plain16 = type { i64, i64 }
%Plain8 = type { i64 }
%OtherRef = type { i64, i8 addrspace(1)* }
%Layout = type { [268435456 x i64] }
@layout.anchor = external global %Layout
@layout.ti = external global %TypeInfo, !RelatedType !0

define void @target(i64 %offset, i32 %allocation) gc "cangjie" {
entry:
  %dst = alloca %Plain16, align 8
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* bitcast (%TypeInfo* @layout.ti to i8*), i32 -2147483648)
  %payload = getelementptr i8, i8 addrspace(1)* %obj, i64 8
  %typed = bitcast i8 addrspace(1)* %payload to %Plain16 addrspace(1)*
  %d = bitcast %Plain16* %dst to i8*
  %s = bitcast %Plain16 addrspace(1)* %typed to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* align 8 %d, i8 addrspace(1)* align 1 %s, i64 16, i1 false)
  call void @use(i8* %d)
  ret void
}
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
declare void @use(i8*)
!0 = !{!"Layout"}

;--- partial-plain.ll
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, %ExtensionDef**, i8*, i8* }
%BitMap = type { i32, [0 x i8] }
%ExtensionDef = type { i32, i8, i8, i16, i8*, i8*, i8*, i8* }
%Plain16 = type { i64, i64 }
%Plain8 = type { i64 }
%OtherRef = type { i64, i8 addrspace(1)* }
%Layout = type { %Plain16, i8 addrspace(1)* }
@layout.anchor = external global %Layout
@layout.ti = external global %TypeInfo, !RelatedType !0

define void @target(i64 %offset, i32 %allocation) gc "cangjie" {
entry:
  %dst = alloca %Plain16, align 8
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* bitcast (%TypeInfo* @layout.ti to i8*), i32 24)
  %payload = getelementptr i8, i8 addrspace(1)* %obj, i64 8
  %typed = bitcast i8 addrspace(1)* %payload to %Plain16 addrspace(1)*
  %d = bitcast %Plain16* %dst to i8*
  %s = bitcast %Plain16 addrspace(1)* %typed to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* align 8 %d, i8 addrspace(1)* align 1 %s, i64 16, i1 false)
  call void @use(i8* %d)
  ret void
}
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
declare void @use(i8*)
!0 = !{!"Layout"}

;--- partial-plain-memmove.ll
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, %ExtensionDef**, i8*, i8* }
%BitMap = type { i32, [0 x i8] }
%ExtensionDef = type { i32, i8, i8, i16, i8*, i8*, i8*, i8* }
%Plain16 = type { i64, i64 }
%Plain8 = type { i64 }
%OtherRef = type { i64, i8 addrspace(1)* }
%Layout = type { %Plain16, i8 addrspace(1)* }
@layout.anchor = external global %Layout
@layout.ti = external global %TypeInfo, !RelatedType !0

define void @target(i64 %offset, i32 %allocation) gc "cangjie" {
entry:
  %dst = alloca %Plain16, align 8
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* bitcast (%TypeInfo* @layout.ti to i8*), i32 24)
  %payload = getelementptr i8, i8 addrspace(1)* %obj, i64 8
  %typed = bitcast i8 addrspace(1)* %payload to %Plain16 addrspace(1)*
  %d = bitcast %Plain16* %dst to i8*
  %s = bitcast %Plain16 addrspace(1)* %typed to i8 addrspace(1)*
  call void @llvm.memmove.p0i8.p1i8.i64(i8* align 8 %d, i8 addrspace(1)* align 1 %s, i64 16, i1 false)
  call void @use(i8* %d)
  ret void
}
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare void @llvm.memmove.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
declare void @use(i8*)
!0 = !{!"Layout"}

;--- helper.ll
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, %ExtensionDef**, i8*, i8* }
%BitMap = type { i32, [0 x i8] }
%ExtensionDef = type { i32, i8, i8, i16, i8*, i8*, i8*, i8* }
%Plain16 = type { i64, i64 }
%Plain8 = type { i64 }
%OtherRef = type { i64, i8 addrspace(1)* }
%Layout = type { i64, i8 addrspace(1)* }
@layout.anchor = external global %Layout
@layout.ti = external global %TypeInfo, !RelatedType !0

define void @target(i64 %offset, i32 %allocation) gc "cangjie" {
entry:
  %dst = alloca %Layout, align 8
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* bitcast (%TypeInfo* @layout.ti to i8*), i32 16)
  %carrier = bitcast i8 addrspace(1)* %obj to i8* addrspace(1)*
  %header = getelementptr i8*, i8* addrspace(1)* %carrier, i32 1
  %payload = bitcast i8* addrspace(1)* %header to i8 addrspace(1)*
  %typed = bitcast i8 addrspace(1)* %payload to %Layout addrspace(1)*
  %d = bitcast %Layout* %dst to i8*
  call void @llvm.cj.memset(i8* %d, i8 0, i64 16, i1 false)
  %s = bitcast %Layout addrspace(1)* %typed to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* align 8 %d, i8 addrspace(1)* align 1 %s, i64 16, i1 false)
  call void @use(i8* %d)
  ret void
}
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
declare void @use(i8*)
declare void @llvm.cj.memset(i8*, i8, i64, i1)
!0 = !{!"Layout"}

;--- legacy-ref-carrier.ll
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, %ExtensionDef**, i8*, i8* }
%BitMap = type { i32, [0 x i8] }
%ExtensionDef = type { i32, i8, i8, i16, i8*, i8*, i8*, i8* }
%Plain16 = type { i64, i64 }
%Plain8 = type { i64 }
%OtherRef = type { i64, i8 addrspace(1)* }
%Layout = type { i64, i8 addrspace(1)* }
@layout.anchor = external global %Layout
@layout.ti = external global %TypeInfo, !RelatedType !0

define void @target(i64 %offset, i32 %allocation) gc "cangjie" {
entry:
  %dst = alloca %OtherRef, align 8
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* bitcast (%TypeInfo* @layout.ti to i8*), i32 16)
  %carrier = bitcast i8 addrspace(1)* %obj to i8* addrspace(1)*
  %header = getelementptr i8*, i8* addrspace(1)* %carrier, i32 1
  %payload = bitcast i8* addrspace(1)* %header to i8 addrspace(1)*
  %typed = bitcast i8 addrspace(1)* %payload to %Layout addrspace(1)*
  %d = bitcast %OtherRef* %dst to i8*
  call void @llvm.cj.memset(i8* %d, i8 0, i64 16, i1 false)
  %s = bitcast %Layout addrspace(1)* %typed to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* align 8 %d, i8 addrspace(1)* align 1 %s, i64 16, i1 false)
  call void @use(i8* %d)
  ret void
}
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
declare void @use(i8*)
declare void @llvm.cj.memset(i8*, i8, i64, i1)
!0 = !{!"Layout"}

;--- before-ref.ll
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, %ExtensionDef**, i8*, i8* }
%BitMap = type { i32, [0 x i8] }
%ExtensionDef = type { i32, i8, i8, i16, i8*, i8*, i8*, i8* }
%Plain16 = type { i64, i64 }
%Plain8 = type { i64 }
%OtherRef = type { i64, i8 addrspace(1)* }
%Layout = type { i64, i8 addrspace(1)* }
@layout.anchor = external global %Layout
@layout.ti = external global %TypeInfo, !RelatedType !0

define void @target(i64 %offset, i32 %allocation) gc "cangjie" {
entry:
  %dst = alloca %Plain8, align 8
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* bitcast (%TypeInfo* @layout.ti to i8*), i32 16)
  %payload = getelementptr i8, i8 addrspace(1)* %obj, i64 8
  %typed = bitcast i8 addrspace(1)* %payload to %Plain8 addrspace(1)*
  %d = bitcast %Plain8* %dst to i8*
  %s = bitcast %Plain8 addrspace(1)* %typed to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* align 8 %d, i8 addrspace(1)* align 1 %s, i64 8, i1 false)
  call void @use(i8* %d)
  ret void
}
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
declare void @use(i8*)
!0 = !{!"Layout"}

;--- after-ref.ll
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, %ExtensionDef**, i8*, i8* }
%BitMap = type { i32, [0 x i8] }
%ExtensionDef = type { i32, i8, i8, i16, i8*, i8*, i8*, i8* }
%Plain16 = type { i64, i64 }
%Plain8 = type { i64 }
%OtherRef = type { i64, i8 addrspace(1)* }
%Layout = type { i64, i8 addrspace(1)*, i64 }
@layout.anchor = external global %Layout
@layout.ti = external global %TypeInfo, !RelatedType !0

define void @target(i64 %offset, i32 %allocation) gc "cangjie" {
entry:
  %dst = alloca %Plain8, align 8
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* bitcast (%TypeInfo* @layout.ti to i8*), i32 24)
  %payload = getelementptr i8, i8 addrspace(1)* %obj, i64 24
  %typed = bitcast i8 addrspace(1)* %payload to %Plain8 addrspace(1)*
  %d = bitcast %Plain8* %dst to i8*
  %s = bitcast %Plain8 addrspace(1)* %typed to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* align 8 %d, i8 addrspace(1)* align 1 %s, i64 8, i1 false)
  call void @use(i8* %d)
  ret void
}
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
declare void @use(i8*)
!0 = !{!"Layout"}

;--- half-ref.ll
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, %ExtensionDef**, i8*, i8* }
%BitMap = type { i32, [0 x i8] }
%ExtensionDef = type { i32, i8, i8, i16, i8*, i8*, i8*, i8* }
%Plain16 = type { i64, i64 }
%Plain8 = type { i64 }
%OtherRef = type { i64, i8 addrspace(1)* }
%Layout = type { i64, i8 addrspace(1)*, i64 }
@layout.anchor = external global %Layout
@layout.ti = external global %TypeInfo, !RelatedType !0

define void @target(i64 %offset, i32 %allocation) gc "cangjie" {
entry:
  %dst = alloca %Plain8, align 8
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* bitcast (%TypeInfo* @layout.ti to i8*), i32 24)
  %payload = getelementptr i8, i8 addrspace(1)* %obj, i64 20
  %typed = bitcast i8 addrspace(1)* %payload to %Plain8 addrspace(1)*
  %d = bitcast %Plain8* %dst to i8*
  %s = bitcast %Plain8 addrspace(1)* %typed to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* align 8 %d, i8 addrspace(1)* align 1 %s, i64 8, i1 false)
  call void @use(i8* %d)
  ret void
}
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
declare void @use(i8*)
!0 = !{!"Layout"}

;--- nested-ref.ll
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, %ExtensionDef**, i8*, i8* }
%BitMap = type { i32, [0 x i8] }
%ExtensionDef = type { i32, i8, i8, i16, i8*, i8*, i8*, i8* }
%Plain16 = type { i64, i64 }
%Plain8 = type { i64 }
%OtherRef = type { i64, i8 addrspace(1)* }
%Layout = type { i64, [2 x i8 addrspace(1)*], i64 }
@layout.anchor = external global %Layout
@layout.ti = external global %TypeInfo, !RelatedType !0

define void @target(i64 %offset, i32 %allocation) gc "cangjie" {
entry:
  %dst = alloca %Plain8, align 8
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* bitcast (%TypeInfo* @layout.ti to i8*), i32 32)
  %payload = getelementptr i8, i8 addrspace(1)* %obj, i64 28
  %typed = bitcast i8 addrspace(1)* %payload to %Plain8 addrspace(1)*
  %d = bitcast %Plain8* %dst to i8*
  %s = bitcast %Plain8 addrspace(1)* %typed to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* align 8 %d, i8 addrspace(1)* align 1 %s, i64 8, i1 false)
  call void @use(i8* %d)
  ret void
}
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
declare void @use(i8*)
!0 = !{!"Layout"}

;--- header.ll
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, %ExtensionDef**, i8*, i8* }
%BitMap = type { i32, [0 x i8] }
%ExtensionDef = type { i32, i8, i8, i16, i8*, i8*, i8*, i8* }
%Plain16 = type { i64, i64 }
%Plain8 = type { i64 }
%OtherRef = type { i64, i8 addrspace(1)* }
%Layout = type { i64, i64 }
@layout.anchor = external global %Layout
@layout.ti = external global %TypeInfo, !RelatedType !0

define void @target(i64 %offset, i32 %allocation) gc "cangjie" {
entry:
  %dst = alloca %Plain16, align 8
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* bitcast (%TypeInfo* @layout.ti to i8*), i32 16)
  %payload = getelementptr i8, i8 addrspace(1)* %obj, i64 0
  %typed = bitcast i8 addrspace(1)* %payload to %Plain16 addrspace(1)*
  %d = bitcast %Plain16* %dst to i8*
  %s = bitcast %Plain16 addrspace(1)* %typed to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* align 8 %d, i8 addrspace(1)* align 1 %s, i64 16, i1 false)
  call void @use(i8* %d)
  ret void
}
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
declare void @use(i8*)
!0 = !{!"Layout"}

;--- negative.ll
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, %ExtensionDef**, i8*, i8* }
%BitMap = type { i32, [0 x i8] }
%ExtensionDef = type { i32, i8, i8, i16, i8*, i8*, i8*, i8* }
%Plain16 = type { i64, i64 }
%Plain8 = type { i64 }
%OtherRef = type { i64, i8 addrspace(1)* }
%Layout = type { i64, i64 }
@layout.anchor = external global %Layout
@layout.ti = external global %TypeInfo, !RelatedType !0

define void @target(i64 %offset, i32 %allocation) gc "cangjie" {
entry:
  %dst = alloca %Plain16, align 8
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* bitcast (%TypeInfo* @layout.ti to i8*), i32 16)
  %payload = getelementptr i8, i8 addrspace(1)* %obj, i64 -8
  %typed = bitcast i8 addrspace(1)* %payload to %Plain16 addrspace(1)*
  %d = bitcast %Plain16* %dst to i8*
  %s = bitcast %Plain16 addrspace(1)* %typed to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* align 8 %d, i8 addrspace(1)* align 1 %s, i64 16, i1 false)
  call void @use(i8* %d)
  ret void
}
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
declare void @use(i8*)
!0 = !{!"Layout"}

;--- out-of-bounds.ll
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, %ExtensionDef**, i8*, i8* }
%BitMap = type { i32, [0 x i8] }
%ExtensionDef = type { i32, i8, i8, i16, i8*, i8*, i8*, i8* }
%Plain16 = type { i64, i64 }
%Plain8 = type { i64 }
%OtherRef = type { i64, i8 addrspace(1)* }
%Layout = type { i64, i64 }
@layout.anchor = external global %Layout
@layout.ti = external global %TypeInfo, !RelatedType !0

define void @target(i64 %offset, i32 %allocation) gc "cangjie" {
entry:
  %dst = alloca %Plain16, align 8
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* bitcast (%TypeInfo* @layout.ti to i8*), i32 16)
  %payload = getelementptr i8, i8 addrspace(1)* %obj, i64 16
  %typed = bitcast i8 addrspace(1)* %payload to %Plain16 addrspace(1)*
  %d = bitcast %Plain16* %dst to i8*
  %s = bitcast %Plain16 addrspace(1)* %typed to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* align 8 %d, i8 addrspace(1)* align 1 %s, i64 16, i1 false)
  call void @use(i8* %d)
  ret void
}
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
declare void @use(i8*)
!0 = !{!"Layout"}

;--- allocation-size.ll
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, %ExtensionDef**, i8*, i8* }
%BitMap = type { i32, [0 x i8] }
%ExtensionDef = type { i32, i8, i8, i16, i8*, i8*, i8*, i8* }
%Plain16 = type { i64, i64 }
%Plain8 = type { i64 }
%OtherRef = type { i64, i8 addrspace(1)* }
%Layout = type { i64, i64 }
@layout.anchor = external global %Layout
@layout.ti = external global %TypeInfo, !RelatedType !0

define void @target(i64 %offset, i32 %allocation) gc "cangjie" {
entry:
  %dst = alloca %Plain16, align 8
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* bitcast (%TypeInfo* @layout.ti to i8*), i32 8)
  %payload = getelementptr i8, i8 addrspace(1)* %obj, i64 8
  %typed = bitcast i8 addrspace(1)* %payload to %Plain16 addrspace(1)*
  %d = bitcast %Plain16* %dst to i8*
  %s = bitcast %Plain16 addrspace(1)* %typed to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* align 8 %d, i8 addrspace(1)* align 1 %s, i64 16, i1 false)
  call void @use(i8* %d)
  ret void
}
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
declare void @use(i8*)
!0 = !{!"Layout"}

;--- multiply-overflow.ll
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, %ExtensionDef**, i8*, i8* }
%BitMap = type { i32, [0 x i8] }
%ExtensionDef = type { i32, i8, i8, i16, i8*, i8*, i8*, i8* }
%Plain16 = type { i64, i64 }
%Plain8 = type { i64 }
%OtherRef = type { i64, i8 addrspace(1)* }
%Layout = type { i64, i64 }
@layout.anchor = external global %Layout
@layout.ti = external global %TypeInfo, !RelatedType !0

define void @target(i64 %offset, i32 %allocation) gc "cangjie" {
entry:
  %dst = alloca %Plain16, align 8
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* bitcast (%TypeInfo* @layout.ti to i8*), i32 16)
  %words = bitcast i8 addrspace(1)* %obj to i64 addrspace(1)*
  %wrap = getelementptr i64, i64 addrspace(1)* %words, i64 2305843009213693953
  %payload = bitcast i64 addrspace(1)* %wrap to i8 addrspace(1)*
  %typed = bitcast i8 addrspace(1)* %payload to %Plain16 addrspace(1)*
  %d = bitcast %Plain16* %dst to i8*
  %s = bitcast %Plain16 addrspace(1)* %typed to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* align 8 %d, i8 addrspace(1)* align 1 %s, i64 16, i1 false)
  call void @use(i8* %d)
  ret void
}
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
declare void @use(i8*)
!0 = !{!"Layout"}

;--- sum-overflow.ll
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, %ExtensionDef**, i8*, i8* }
%BitMap = type { i32, [0 x i8] }
%ExtensionDef = type { i32, i8, i8, i16, i8*, i8*, i8*, i8* }
%Plain16 = type { i64, i64 }
%Plain8 = type { i64 }
%OtherRef = type { i64, i8 addrspace(1)* }
%Layout = type { i64, i64 }
@layout.anchor = external global %Layout
@layout.ti = external global %TypeInfo, !RelatedType !0

define void @target(i64 %offset, i32 %allocation) gc "cangjie" {
entry:
  %dst = alloca %Plain16, align 8
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* bitcast (%TypeInfo* @layout.ti to i8*), i32 16)
  %far = getelementptr i8, i8 addrspace(1)* %obj, i64 9223372036854775807
  %wrap = getelementptr i8, i8 addrspace(1)* %far, i64 9223372036854775807
  %payload = getelementptr i8, i8 addrspace(1)* %wrap, i64 10
  %typed = bitcast i8 addrspace(1)* %payload to %Plain16 addrspace(1)*
  %d = bitcast %Plain16* %dst to i8*
  %s = bitcast %Plain16 addrspace(1)* %typed to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* align 8 %d, i8 addrspace(1)* align 1 %s, i64 16, i1 false)
  call void @use(i8* %d)
  ret void
}
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
declare void @use(i8*)
!0 = !{!"Layout"}

;--- wide-index.ll
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, %ExtensionDef**, i8*, i8* }
%BitMap = type { i32, [0 x i8] }
%ExtensionDef = type { i32, i8, i8, i16, i8*, i8*, i8*, i8* }
%Plain16 = type { i64, i64 }
%Plain8 = type { i64 }
%OtherRef = type { i64, i8 addrspace(1)* }
%Layout = type { i64, i64 }
@layout.anchor = external global %Layout
@layout.ti = external global %TypeInfo, !RelatedType !0

define void @target(i64 %offset, i32 %allocation) gc "cangjie" {
entry:
  %dst = alloca %Plain16, align 8
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* bitcast (%TypeInfo* @layout.ti to i8*), i32 16)
  %payload = getelementptr i8, i8 addrspace(1)* %obj, i128 18446744073709551624
  %typed = bitcast i8 addrspace(1)* %payload to %Plain16 addrspace(1)*
  %d = bitcast %Plain16* %dst to i8*
  %s = bitcast %Plain16 addrspace(1)* %typed to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* align 8 %d, i8 addrspace(1)* align 1 %s, i64 16, i1 false)
  call void @use(i8* %d)
  ret void
}
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
declare void @use(i8*)
!0 = !{!"Layout"}

;--- dynamic-offset.ll
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, %ExtensionDef**, i8*, i8* }
%BitMap = type { i32, [0 x i8] }
%ExtensionDef = type { i32, i8, i8, i16, i8*, i8*, i8*, i8* }
%Plain16 = type { i64, i64 }
%Plain8 = type { i64 }
%OtherRef = type { i64, i8 addrspace(1)* }
%Layout = type { i64, i8 addrspace(1)* }
@layout.anchor = external global %Layout
@layout.ti = external global %TypeInfo, !RelatedType !0

define void @target(i64 %offset, i32 %allocation) gc "cangjie" {
entry:
  %dst = alloca %Plain16, align 8
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* bitcast (%TypeInfo* @layout.ti to i8*), i32 16)
  %payload = getelementptr i8, i8 addrspace(1)* %obj, i64 %offset
  %typed = bitcast i8 addrspace(1)* %payload to %Plain16 addrspace(1)*
  %d = bitcast %Plain16* %dst to i8*
  %s = bitcast %Plain16 addrspace(1)* %typed to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* align 8 %d, i8 addrspace(1)* align 1 %s, i64 16, i1 false)
  call void @use(i8* %d)
  ret void
}
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
declare void @use(i8*)
!0 = !{!"Layout"}

;--- dynamic-allocation.ll
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, %ExtensionDef**, i8*, i8* }
%BitMap = type { i32, [0 x i8] }
%ExtensionDef = type { i32, i8, i8, i16, i8*, i8*, i8*, i8* }
%Plain16 = type { i64, i64 }
%Plain8 = type { i64 }
%OtherRef = type { i64, i8 addrspace(1)* }
%Layout = type { i64, i8 addrspace(1)* }
@layout.anchor = external global %Layout
@layout.ti = external global %TypeInfo, !RelatedType !0

define void @target(i64 %offset, i32 %allocation) gc "cangjie" {
entry:
  %dst = alloca %Plain16, align 8
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* bitcast (%TypeInfo* @layout.ti to i8*), i32 %allocation)
  %payload = getelementptr i8, i8 addrspace(1)* %obj, i64 8
  %typed = bitcast i8 addrspace(1)* %payload to %Plain16 addrspace(1)*
  %d = bitcast %Plain16* %dst to i8*
  %s = bitcast %Plain16 addrspace(1)* %typed to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* align 8 %d, i8 addrspace(1)* align 1 %s, i64 16, i1 false)
  call void @use(i8* %d)
  ret void
}
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
declare void @use(i8*)
!0 = !{!"Layout"}

;--- unknown-layout.ll
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, %ExtensionDef**, i8*, i8* }
%BitMap = type { i32, [0 x i8] }
%ExtensionDef = type { i32, i8, i8, i16, i8*, i8*, i8*, i8* }
%Plain16 = type { i64, i64 }
%Plain8 = type { i64 }
%OtherRef = type { i64, i8 addrspace(1)* }
%Layout = type { i64, i8 addrspace(1)* }
@layout.anchor = external global %Layout
@layout.ti = external global %TypeInfo

define void @target(i64 %offset, i32 %allocation) gc "cangjie" {
entry:
  %dst = alloca %Plain16, align 8
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* bitcast (%TypeInfo* @layout.ti to i8*), i32 16)
  %payload = getelementptr i8, i8 addrspace(1)* %obj, i64 8
  %typed = bitcast i8 addrspace(1)* %payload to %Plain16 addrspace(1)*
  %d = bitcast %Plain16* %dst to i8*
  %s = bitcast %Plain16 addrspace(1)* %typed to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* align 8 %d, i8 addrspace(1)* align 1 %s, i64 16, i1 false)
  call void @use(i8* %d)
  ret void
}
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
declare void @use(i8*)
!0 = !{!"Layout"}

;--- reference-vector-unsupported.ll
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, %ExtensionDef**, i8*, i8* }
%BitMap = type { i32, [0 x i8] }
%ExtensionDef = type { i32, i8, i8, i16, i8*, i8*, i8*, i8* }
%Plain16 = type { i64, i64 }
%Plain8 = type { i64 }
%OtherRef = type { i64, i8 addrspace(1)* }
%Layout = type { <2 x i8 addrspace(1)*> }
@layout.anchor = external global %Layout
@layout.ti = external global %TypeInfo, !RelatedType !0

define void @target(i64 %offset, i32 %allocation) gc "cangjie" {
entry:
  %dst = alloca %Plain16, align 8
  %obj = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* bitcast (%TypeInfo* @layout.ti to i8*), i32 16)
  %payload = getelementptr i8, i8 addrspace(1)* %obj, i64 8
  %typed = bitcast i8 addrspace(1)* %payload to %Plain16 addrspace(1)*
  %d = bitcast %Plain16* %dst to i8*
  %s = bitcast %Plain16 addrspace(1)* %typed to i8 addrspace(1)*
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* align 8 %d, i8 addrspace(1)* align 1 %s, i64 16, i1 false)
  call void @use(i8* %d)
  ret void
}
declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
declare void @use(i8*)
!0 = !{!"Layout"}
