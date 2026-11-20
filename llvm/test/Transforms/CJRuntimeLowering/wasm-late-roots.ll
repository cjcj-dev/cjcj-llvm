; RUN: opt -passes=cj-runtime-lowering,verify -S %s | FileCheck %s
target datalayout = "e-p:32:32-p1:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-wasi"

declare i8 addrspace(1)* @llvm.cj.alloca.generic(i8*, i32)
declare void @collect()
declare "cj.wasm.base" i8 addrspace(1)* @known()
declare void @consume(i8 addrspace(1)*)
declare void @write(i8 addrspace(1)* sret(i8))

; CHECK-LABEL: define i8 @late(
; CHECK: %first = call noalias i8 addrspace(1)* @CJ_MCC_NewObject
; CHECK-NOT: @cjw_push_frame
; CHECK: %field = getelementptr i8, i8 addrspace(1)* %first, i32 %offset
; CHECK: body:
; CHECK: store volatile i8 addrspace(1)* %field,
; CHECK: store volatile i32 1,
; CHECK-NEXT: call void @cjw_push_frame(
; CHECK-NEXT: %next = call noalias i8 addrspace(1)* @CJ_MCC_NewObject
; CHECK-NEXT: call void @cjw_pop_frame(
; CHECK-NEXT: %v = load i8, i8 addrspace(1)* %field
define i8 @late(i8* %ti, i32 %offset) {
  %first = call i8 addrspace(1)* @llvm.cj.alloca.generic(i8* %ti, i32 16), !TrustedSize !1
  %field = getelementptr i8, i8 addrspace(1)* %first, i32 %offset
  br label %body
body:
  %next = call i8 addrspace(1)* @llvm.cj.alloca.generic(i8* %ti, i32 12), !TrustedSize !1
  %v = load i8, i8 addrspace(1)* %field
  ret i8 %v
}

; CHECK-LABEL: define void @unknown(
; CHECK: store volatile i8 addrspace(1)* %arg,
; CHECK: call void @cjw_push_frame(
; CHECK-NEXT: call void @collect()
; CHECK-NEXT: call void @cjw_pop_frame(
; CHECK: call void @consume(i8 addrspace(1)* %arg)
define void @unknown(i8 addrspace(1)* noalias sret(i8) %arg) {
  call void @collect()
  call void @consume(i8 addrspace(1)* %arg)
  ret void
}

; CHECK-LABEL: define void @known_edge(
; CHECK: store volatile i8 addrspace(1)* %arg,
; CHECK: call void @cjw_push_frame(
; CHECK-NEXT: %result = call i8 addrspace(1)* @known()
; CHECK: store volatile i8 addrspace(1)* %arg,
; CHECK: store volatile i8 addrspace(1)* %result,
; CHECK: store volatile i32 2,
; CHECK: call void @consume(i8 addrspace(1)* %arg)
; CHECK: call void @consume(i8 addrspace(1)* %result)
define void @known_edge(i8 addrspace(1)* "cj.wasm.base" %arg) {
  %result = call i8 addrspace(1)* @known()
  call void @consume(i8 addrspace(1)* %arg)
  call void @consume(i8 addrspace(1)* %result)
  ret void
}

%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }
%RefPayload = type { i8 addrspace(1)* }
@Int64.ti = external global %TypeInfo, !RelatedType !2
@Record.ti = external global %TypeInfo, !RelatedType !3

; CHECK-LABEL: define void @plain_stack(
; CHECK: [[OBJ:%[^ ]+]] = alloca { %TypeInfo*, i32, i64 }, align 8
; CHECK: %wasm.root.ranges = alloca { i32, [1 x { i8*, i32 }] }
; CHECK: call void @llvm.memset.p0i8.i64(i8* align 8 {{%[^ ]+}}, i8 0, i64 16, i1 false)
; CHECK: store i32 16,
; CHECK: [[STACK:%[^ ]+]] = addrspacecast { %TypeInfo*, i32, i64 }* [[OBJ]] to i8 addrspace(1)*
; CHECK: call void @cjw_push_frame(
; CHECK-NEXT: call void @write(i8 addrspace(1)* sret(i8) [[STACK]])
; CHECK-NEXT: call void @cjw_pop_frame(
define void @plain_stack() {
  %s = call i8 addrspace(1)* @llvm.cj.alloca.generic(i8* bitcast (%TypeInfo* @Int64.ti to i8*), i32 8), !TrustedSize !1
  call void @write(i8 addrspace(1)* sret(i8) %s)
  ret void
}

; CHECK-LABEL: define void @ref_stack(
; CHECK: alloca { %TypeInfo*, i32, %RefPayload }, align 8
; CHECK: call void @llvm.memset.p0i8.i64(i8* align 8 {{%[^ ]+}}, i8 0, i64 12, i1 false)
; CHECK: store i32 12,
; CHECK: [[STACK:%[^ ]+]] = addrspacecast
; CHECK: call void @cjw_push_frame(
; CHECK-NEXT: call void @write(i8 addrspace(1)* sret(i8) [[STACK]])
; CHECK-NEXT: call void @cjw_pop_frame(
define void @ref_stack() {
  %s = call i8 addrspace(1)* @llvm.cj.alloca.generic(i8* bitcast (%TypeInfo* @Record.ti to i8*), i32 4), !TrustedSize !1
  call void @write(i8 addrspace(1)* sret(i8) %s)
  ret void
}

; The stack object is published in place as a range, and its AS1 views are
; slots (they point outside the heap and are ignored by the collector).
%Two = type { i8 addrspace(1)*, i8 addrspace(1)* }
@Pair.ti = external global %TypeInfo, !RelatedType !4
; CHECK-LABEL: define i8 addrspace(1)* @one_live_field(
; CHECK: alloca { i8*, i8*, i32, [2 x i8 addrspace(1)*] }
; CHECK: %wasm.root.ranges
; CHECK: store i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %first
; CHECK: store i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %second
; CHECK: call void @cjw_push_frame(
; CHECK-NEXT: call void @collect()
; CHECK-NEXT: call void @cjw_pop_frame(
; CHECK: %result = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %first
define i8 addrspace(1)* @one_live_field(i8 addrspace(1)* %v) {
  %s = call i8 addrspace(1)* @llvm.cj.alloca.generic(i8* bitcast (%TypeInfo* @Pair.ti to i8*), i32 8), !TrustedSize !1
  %p = getelementptr i8, i8 addrspace(1)* %s, i32 8
  %first = bitcast i8 addrspace(1)* %p to i8 addrspace(1)* addrspace(1)*
  %second = getelementptr i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %first, i32 1
  store i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %first
  store i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %second
  call void @collect()
  br label %exit
exit:
  store i8 addrspace(1)* null, i8 addrspace(1)* addrspace(1)* %second
  %result = load i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)* %first
  ret i8 addrspace(1)* %result
}

; The merged pointer is derived on one edge and unknown on the other; it is
; published as is and the use after the call keeps the original value.
; CHECK-LABEL: define i8 @mixed(
; CHECK: %maybe = phi i8 addrspace(1)* [ %field, %left ], [ %unknown, %right ]
; CHECK: store volatile i8 addrspace(1)* %maybe,
; CHECK: call void @cjw_push_frame(
; CHECK-NEXT: call void @collect()
; CHECK-NEXT: call void @cjw_pop_frame(
; CHECK-NEXT: %byte = load i8, i8 addrspace(1)* %maybe
define i8 @mixed(i1 %which, i8 addrspace(1)* "cj.wasm.base" %object, i8 addrspace(1)* %unknown, i32 %offset) {
  br i1 %which, label %left, label %right
left:
  %field = getelementptr i8, i8 addrspace(1)* %object, i32 %offset
  br label %join
right:
  br label %join
join:
  %maybe = phi i8 addrspace(1)* [ %field, %left ], [ %unknown, %right ]
  call void @collect()
  %byte = load i8, i8 addrspace(1)* %maybe
  ret i8 %byte
}

!1 = !{}
!2 = !{!"Int64.Type"}
!3 = !{!"RefPayload"}
!4 = !{!"Two"}
