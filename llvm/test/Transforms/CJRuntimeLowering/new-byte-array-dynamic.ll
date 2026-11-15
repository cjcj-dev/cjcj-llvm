; RUN: opt -passes=cj-runtime-lowering,verify -S < %s | FileCheck %s
; RUN: opt -cj-runtime-lowering -verify -S < %s | FileCheck %s
; RUN: opt -passes=cj-runtime-lowering,verify -enable-cangjie-new-array-fastpath=false -S < %s | FileCheck %s --check-prefix=OFF
; RUN: opt -passes=cj-runtime-lowering,verify -cangjie-JIT -S < %s | FileCheck %s --check-prefix=OFF
; RUN: opt -passes=cj-runtime-lowering,verify -mtriple=armv7-unknown-linux-gnueabihf -S < %s | FileCheck %s --check-prefix=OFF
; RUN: opt -passes='cj-runtime-lowering,function(simplifycfg),verify' -S < %s | FileCheck %s --check-prefix=MERGE
; RUN: opt -passes=cj-runtime-lowering,cj-rewrite-statepoint,verify -S < %s > %t
; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu < %t | FileCheck %s --check-prefix=X86
; RUN: llc --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu < %t | FileCheck %s --check-prefix=ARM
; REQUIRES: x86-registered-target, aarch64-registered-target
;
; Only a primitive byte array gets the dynamic fast path. Ineligible lengths
; branch to the original runtime entry, never to an artificial TLAB size.
target triple = "x86_64-unknown-linux-gnu"
target datalayout = "e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i16, i32*, i8*, i8*, i8*, %TypeInfo*, i8**, i8*, i8* }
%OneByteStruct = type { i8 }
%Layout.Bytes = type { i64, [0 x i8] }
@Bytes.ti = constant %TypeInfo { i8* null, i8 -126, i8 0, i16 0, i32 1, i8* null, i32 0, i8 1, i8 0, i16 0, i32* null, i8* null, i8* null, i8* null, %TypeInfo* null, i8** null, i8* null, i8* null }, !RelatedType !0
%Layout.Words = type { i64, [0 x i16] }
@Words.ti = constant %TypeInfo { i8* null, i8 -126, i8 0, i16 0, i32 2, i8* null, i32 0, i8 1, i8 0, i16 0, i32* null, i8* null, i8* null, i8* null, %TypeInfo* null, i8** null, i8* null, i8* null }, !RelatedType !1
%Layout.Struct = type { i64, [0 x %OneByteStruct] }
@Struct.ti = constant %TypeInfo { i8* null, i8 -126, i8 0, i16 0, i32 1, i8* null, i32 0, i8 1, i8 0, i16 0, i32* null, i8* null, i8* null, i8* null, %TypeInfo* null, i8** null, i8* null, i8* null }, !RelatedType !2
%Layout.Refs = type { i64, [0 x i8 addrspace(1)*] }
@Refs.ti = constant %TypeInfo { i8* null, i8 -126, i8 0, i16 0, i32 8, i8* null, i32 0, i8 1, i8 0, i16 0, i32* null, i8* null, i8* null, i8* null, %TypeInfo* null, i8** null, i8* null, i8* null }, !RelatedType !3
%Layout.Empty = type { i64, [0 x {}] }
@Empty.ti = constant %TypeInfo { i8* null, i8 -126, i8 0, i16 0, i32 0, i8* null, i32 0, i8 1, i8 0, i16 0, i32* null, i8* null, i8* null, i8* null, %TypeInfo* null, i8** null, i8* null, i8* null }, !RelatedType !4

; CHECK-LABEL: define i8 addrspace(1)* @bytes(
; CHECK: array.check:
; CHECK: %[[FITS:.*]] = icmp ult i64 %n, 4096
; CHECK-NEXT: br i1 %[[FITS]], label %array.fast, label %array.slow
; CHECK: array.fast:
; CHECK-NEXT: %[[PAD:.*]] = add i64 %n, 23
; CHECK-NEXT: %[[SIZE:.*]] = and i64 %[[PAD]], -8
; CHECK-NEXT: %[[FAST:.*]] = call noalias i8 addrspace(1)* @CJ_MCC_NewArray8({{.*}}i64 %n, i64 %[[SIZE]]){{.*}}!fast_new_array
; CHECK-NEXT: br label %entry
; CHECK: array.slow:
; CHECK-NEXT: %[[SLOW:.*]] = call noalias i8 addrspace(1)* @CJ_MCC_NewArray8({{.*}}i64 %n, i64 poison)
; CHECK-NEXT: br label %entry
; CHECK: %[[RESULT:.*]] = phi i8 addrspace(1)* [ %[[FAST]], %array.fast ], [ %[[SLOW]], %array.slow ]
; CHECK-NEXT: ret i8 addrspace(1)* %[[RESULT]]
; OFF-LABEL: define i8 addrspace(1)* @bytes(
; OFF-NOT: icmp
; OFF: call noalias i8 addrspace(1)* @CJ_MCC_NewArray8({{.*}}i64 %n, i64 poison)
; OFF-NOT: !fast_new_array
; OFF: ret
; MERGE-LABEL: define i8 addrspace(1)* @bytes(
; MERGE: icmp ult i64 %n, 4096
; MERGE: br i1
; MERGE: call noalias i8 addrspace(1)* @CJ_MCC_NewArray8({{.*}}i64 %n, i64 %{{.*}}){{.*}}!fast_new_array
; MERGE: call noalias i8 addrspace(1)* @CJ_MCC_NewArray8({{.*}}i64 %n, i64 poison)
; MERGE-LABEL: define i8 addrspace(1)* @two(
; X86-LABEL: bytes:
; X86: cmpq $4096,
; X86: .LNewArrayFastPath
; X86: leaq (%rax,%rdx), %r8
; X86-NEXT: cmpq %r10, %r8
; X86-NEXT: jg
; X86: movq %rsi, 8(%rax)
; X86: callq CJ_MCC_NewArray8
; ARM-LABEL: bytes:
; ARM: cmp x{{[0-9]+}}, #1, lsl #12
; ARM: .LNewArrayFastPath
; ARM: add x7, x5, x2
; ARM-NEXT: cmp x7, x6
; ARM-NEXT: b.gt
; ARM: str x1, [x5, #8]
; ARM: bl CJ_MCC_NewArray8
define i8 addrspace(1)* @bytes(i64 %n) gc "cangjie" {
entry:
  %p = call i8 addrspace(1)* @llvm.cj.malloc.array(i8* bitcast (%TypeInfo* @Bytes.ti to i8*), i64 %n, i64 1)
  ret i8 addrspace(1)* %p
}

; Exercise traversal after splitting a block: the following allocation must
; also lower, and the first result remains live over the second statepoint.
; CHECK-LABEL: define i8 addrspace(1)* @two(
; CHECK: icmp ult i64 %n, 4096
; CHECK: icmp ult i64 %m, 4096
; CHECK-NOT: @llvm.cj.malloc.array
; CHECK: ret
define i8 addrspace(1)* @two(i64 %n, i64 %m) gc "cangjie" {
  %a = call i8 addrspace(1)* @llvm.cj.malloc.array(i8* bitcast (%TypeInfo* @Bytes.ti to i8*), i64 %n, i64 1)
  %b = call i8 addrspace(1)* @llvm.cj.malloc.array(i8* bitcast (%TypeInfo* @Bytes.ti to i8*), i64 %m, i64 1)
  call void @use(i8 addrspace(1)* %b)
  ret i8 addrspace(1)* %a
}

; A pre-existing multi-predecessor join must keep every incoming edge when its
; phi and prefix instructions move to the new range-check block.
; CHECK-LABEL: define i8 addrspace(1)* @join(
; CHECK: left:
; CHECK-NEXT: br label %array.check
; CHECK: right:
; CHECK-NEXT: br label %array.check
; CHECK: array.check:
; CHECK-NEXT: %n = phi i64 [ %a, %left ], [ %b, %right ]
; CHECK-NEXT: %{{.*}} = icmp ult i64 %n, 4096
; CHECK: ret
define i8 addrspace(1)* @join(i1 %c, i64 %a, i64 %b) gc "cangjie" {
entry:
  br i1 %c, label %left, label %right
left:
  br label %alloc
right:
  br label %alloc
alloc:
  %n = phi i64 [ %a, %left ], [ %b, %right ]
  %p = call i8 addrspace(1)* @llvm.cj.malloc.array(i8* bitcast (%TypeInfo* @Bytes.ti to i8*), i64 %n, i64 1)
  ret i8 addrspace(1)* %p
}

; Both exceptional edges carry the original handler phi value. The normal
; successor still receives the merged allocation from the original block.
; CHECK-LABEL: define i8 addrspace(1)* @with_handler(
; CHECK: invoke noalias i8 addrspace(1)* @CJ_MCC_NewArray8({{.*}}i64 %n, i64 %{{.*}})
; CHECK-NEXT: to label %alloc unwind label %handler, !fast_new_array
; CHECK: invoke noalias i8 addrspace(1)* @CJ_MCC_NewArray8({{.*}}i64 %n, i64 poison)
; CHECK-NEXT: to label %alloc unwind label %handler
; CHECK: alloc:
; CHECK-NEXT: %[[MERGED:.*]] = phi i8 addrspace(1)*
; CHECK-NEXT: br label %done
; CHECK: phi i8 addrspace(1)* [ %[[MERGED]], %alloc ]
; CHECK: phi i32 [ 0, %entry ], [ 1, %array.slow ], [ 1, %array.fast ]
define i8 addrspace(1)* @with_handler(i64 %n) gc "cangjie" personality i8* bitcast (i32 (...)* @__gxx_personality_v0 to i8*) {
entry:
  invoke void @may_throw() to label %alloc unwind label %handler
alloc:
  %p = invoke i8 addrspace(1)* @llvm.cj.malloc.array(i8* bitcast (%TypeInfo* @Bytes.ti to i8*), i64 %n, i64 1) to label %done unwind label %handler
done:
  %r = phi i8 addrspace(1)* [ %p, %alloc ]
  ret i8 addrspace(1)* %r
handler:
  %which = phi i32 [ 0, %entry ], [ 1, %alloc ]
  %lp = landingpad { i8*, i32 } cleanup
  call void @observe(i32 %which)
  ret i8 addrspace(1)* null
}

; CHECK-LABEL: @word(
; CHECK-NOT: icmp
; CHECK: call noalias i8 addrspace(1)* @CJ_MCC_NewArray16({{.*}}i64 %n, i64 poison)
; CHECK-NOT: !fast_new_array
; CHECK: ret
define i8 addrspace(1)* @word(i64 %n) gc "cangjie" {
 %p = call i8 addrspace(1)* @llvm.cj.malloc.array(i8* bitcast (%TypeInfo* @Words.ti to i8*), i64 %n, i64 2)
 ret i8 addrspace(1)* %p
}

; CHECK-LABEL: @struct_byte(
; CHECK-NOT: icmp
; CHECK: call noalias i8 addrspace(1)* @CJ_MCC_NewArray({{.*}}i64 %n, i64 poison)
; CHECK-NOT: !fast_new_array
; CHECK: ret
define i8 addrspace(1)* @struct_byte(i64 %n) gc "cangjie" {
 %p = call i8 addrspace(1)* @llvm.cj.malloc.array(i8* bitcast (%TypeInfo* @Struct.ti to i8*), i64 %n, i64 1)
 ret i8 addrspace(1)* %p
}

; CHECK-LABEL: @reference(
; CHECK-NOT: icmp
; CHECK: call noalias i8 addrspace(1)* @CJ_MCC_NewObjArray({{.*}}i64 %n, i64 poison)
; CHECK-NOT: !fast_new_array
; CHECK: ret
define i8 addrspace(1)* @reference(i64 %n) gc "cangjie" {
 %p = call i8 addrspace(1)* @llvm.cj.malloc.array(i8* bitcast (%TypeInfo* @Refs.ti to i8*), i64 %n, i64 1)
 ret i8 addrspace(1)* %p
}

; CHECK-LABEL: @empty(
; CHECK-NOT: icmp
; CHECK: call noalias i8 addrspace(1)* @CJ_MCC_NewArray({{.*}}i64 %n, i64 poison)
; CHECK-NOT: !fast_new_array
; CHECK: ret
define i8 addrspace(1)* @empty(i64 %n) gc "cangjie" {
 %p = call i8 addrspace(1)* @llvm.cj.malloc.array(i8* bitcast (%TypeInfo* @Empty.ti to i8*), i64 %n, i64 0)
 ret i8 addrspace(1)* %p
}

; CHECK-LABEL: @unknown(
; CHECK-NOT: icmp
; CHECK: call noalias i8 addrspace(1)* @CJ_MCC_NewArray8({{.*}}i64 %n, i64 poison)
; CHECK-NOT: !fast_new_array
; CHECK: ret
define i8 addrspace(1)* @unknown(i64 %n, i64 %size) gc "cangjie" {
 %p = call i8 addrspace(1)* @llvm.cj.malloc.array(i8* bitcast (%TypeInfo* @Bytes.ti to i8*), i64 %n, i64 %size)
 ret i8 addrspace(1)* %p
}

; CHECK-LABEL: @constant_zero(
; CHECK-NOT: icmp
; CHECK: call noalias i8 addrspace(1)* @CJ_MCC_NewArray8({{.*}}i64 0, i64 16){{.*}}!fast_new_array
; CHECK-NEXT: ret
define i8 addrspace(1)* @constant_zero() gc "cangjie" {
 %p = call i8 addrspace(1)* @llvm.cj.malloc.array(i8* bitcast (%TypeInfo* @Bytes.ti to i8*), i64 0, i64 1)
 ret i8 addrspace(1)* %p
}

; CHECK-LABEL: @constant_one(
; CHECK-NOT: icmp
; CHECK: call noalias i8 addrspace(1)* @CJ_MCC_NewArray8({{.*}}i64 1, i64 24){{.*}}!fast_new_array
; CHECK-NEXT: ret
define i8 addrspace(1)* @constant_one() gc "cangjie" {
 %p = call i8 addrspace(1)* @llvm.cj.malloc.array(i8* bitcast (%TypeInfo* @Bytes.ti to i8*), i64 1, i64 1)
 ret i8 addrspace(1)* %p
}

; CHECK-LABEL: @constant_twenty(
; CHECK-NOT: icmp
; CHECK: call noalias i8 addrspace(1)* @CJ_MCC_NewArray8({{.*}}i64 20, i64 40){{.*}}!fast_new_array
; CHECK-NEXT: ret
define i8 addrspace(1)* @constant_twenty() gc "cangjie" {
 %p = call i8 addrspace(1)* @llvm.cj.malloc.array(i8* bitcast (%TypeInfo* @Bytes.ti to i8*), i64 20, i64 1)
 ret i8 addrspace(1)* %p
}

; CHECK-LABEL: @constant_limit_minus_one(
; CHECK-NOT: icmp
; CHECK: call noalias i8 addrspace(1)* @CJ_MCC_NewArray8({{.*}}i64 4095, i64 4112){{.*}}!fast_new_array
; CHECK-NEXT: ret
define i8 addrspace(1)* @constant_limit_minus_one() gc "cangjie" {
 %p = call i8 addrspace(1)* @llvm.cj.malloc.array(i8* bitcast (%TypeInfo* @Bytes.ti to i8*), i64 4095, i64 1)
 ret i8 addrspace(1)* %p
}

; CHECK-LABEL: @constant_limit(
; CHECK-NOT: icmp
; CHECK: call noalias i8 addrspace(1)* @CJ_MCC_NewArray8({{.*}}i64 4096, i64 poison)
; CHECK-NEXT: ret
define i8 addrspace(1)* @constant_limit() gc "cangjie" {
 %p = call i8 addrspace(1)* @llvm.cj.malloc.array(i8* bitcast (%TypeInfo* @Bytes.ti to i8*), i64 4096, i64 1)
 ret i8 addrspace(1)* %p
}

; CHECK-LABEL: @constant_limit_plus_one(
; CHECK-NOT: icmp
; CHECK: call noalias i8 addrspace(1)* @CJ_MCC_NewArray8({{.*}}i64 4097, i64 poison)
; CHECK-NEXT: ret
define i8 addrspace(1)* @constant_limit_plus_one() gc "cangjie" {
 %p = call i8 addrspace(1)* @llvm.cj.malloc.array(i8* bitcast (%TypeInfo* @Bytes.ti to i8*), i64 4097, i64 1)
 ret i8 addrspace(1)* %p
}

; CHECK-LABEL: @constant_negative(
; CHECK-NOT: icmp
; CHECK: call noalias i8 addrspace(1)* @CJ_MCC_NewArray8({{.*}}i64 -1, i64 poison)
; CHECK-NEXT: ret
define i8 addrspace(1)* @constant_negative() gc "cangjie" {
 %p = call i8 addrspace(1)* @llvm.cj.malloc.array(i8* bitcast (%TypeInfo* @Bytes.ti to i8*), i64 -1, i64 1)
 ret i8 addrspace(1)* %p
}

; CHECK-LABEL: @constant_min(
; CHECK-NOT: icmp
; CHECK: call noalias i8 addrspace(1)* @CJ_MCC_NewArray8({{.*}}i64 -9223372036854775808, i64 poison)
; CHECK-NEXT: ret
define i8 addrspace(1)* @constant_min() gc "cangjie" {
 %p = call i8 addrspace(1)* @llvm.cj.malloc.array(i8* bitcast (%TypeInfo* @Bytes.ti to i8*), i64 -9223372036854775808, i64 1)
 ret i8 addrspace(1)* %p
}

; CHECK-LABEL: @constant_max(
; CHECK-NOT: icmp
; CHECK: call noalias i8 addrspace(1)* @CJ_MCC_NewArray8({{.*}}i64 9223372036854775807, i64 poison)
; CHECK-NEXT: ret
define i8 addrspace(1)* @constant_max() gc "cangjie" {
 %p = call i8 addrspace(1)* @llvm.cj.malloc.array(i8* bitcast (%TypeInfo* @Bytes.ti to i8*), i64 9223372036854775807, i64 1)
 ret i8 addrspace(1)* %p
}

declare i8 addrspace(1)* @llvm.cj.malloc.array(i8*, i64, i64)
declare void @use(i8 addrspace(1)*)
declare void @observe(i32)
declare void @may_throw()
declare i32 @__gxx_personality_v0(...)
!0 = !{!"Layout.Bytes"}
!1 = !{!"Layout.Words"}
!2 = !{!"Layout.Struct"}
!3 = !{!"Layout.Refs"}
!4 = !{!"Layout.Empty"}
