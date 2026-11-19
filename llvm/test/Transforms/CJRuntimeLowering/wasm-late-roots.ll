; RUN: opt -passes=cj-runtime-lowering,verify -cj-wasm-root-version=1 -S %s | FileCheck %s
; RUN: sed '/^!llvm.module.flags/d' %s | opt -passes=cj-runtime-lowering,verify -S | FileCheck %s --check-prefix=OLD
; RUN: sed '/^!llvm.module.flags/d' %s | not --crash opt -cj-wasm-root-version=1 -passes=cj-runtime-lowering -disable-output 2>&1 | FileCheck %s --check-prefix=VERSION
; VERSION: missing or incompatible cj.wasm.root.version
; OLD-NOT: @cjw_root_frame_push
target datalayout = "e-p:32:32-p1:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-wasi"

declare i8 addrspace(1)* @llvm.cj.alloca.generic(i8*, i32)
declare void @collect()
declare "cj.wasm.base" i8 addrspace(1)* @known()
declare void @consume(i8 addrspace(1)*)
declare void @write(i8 addrspace(1)* sret(i8))

; CHECK-LABEL: define i8 @late(
; CHECK-NOT: call void @cjw_root_frame_push
; CHECK: %first = call noalias i8 addrspace(1)* @CJ_MCC_NewObject
; CHECK: store volatile i8 addrspace(1)* %first,
; CHECK: call void @cjw_root_frame_push
; CHECK: %next = call noalias i8 addrspace(1)* @CJ_MCC_NewObject
; CHECK: [[NEW:%[^ ]+]] = load volatile i8 addrspace(1)*
; CHECK: call void @cjw_root_frame_pop
; CHECK: [[FIELD:%[^ ]+]] = getelementptr i8, i8 addrspace(1)* [[NEW]], i32 %offset
; CHECK: load i8, i8 addrspace(1)* [[FIELD]]
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
; CHECK-NOT: @cjw_root_frame_push
; CHECK: ret void
define void @unknown(i8 addrspace(1)* noalias sret(i8) %arg) {
  call void @collect()
  call void @consume(i8 addrspace(1)* %arg)
  ret void
}

; CHECK-LABEL: define void @known_edge(
; CHECK: store volatile i8 addrspace(1)* %arg
; CHECK: call i8 addrspace(1)* @known
; CHECK: [[ARG:%[^ ]+]] = load volatile i8 addrspace(1)*
; CHECK: store volatile i8 addrspace(1)* %result
; CHECK: call void @consume(i8 addrspace(1)* [[ARG]])
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
; CHECK: addrspacecast
; CHECK-NOT: @cjw_root_frame_push
; CHECK: call void @write
; CHECK: ret void
define void @plain_stack() {
  %s = call i8 addrspace(1)* @llvm.cj.alloca.generic(i8* bitcast (%TypeInfo* @Int64.ti to i8*), i32 8), !TrustedSize !1
  call void @write(i8 addrspace(1)* sret(i8) %s)
  ret void
}

; CHECK-LABEL: define void @ref_stack(
; CHECK: [[STACK:%[^ ]+]] = addrspacecast
; CHECK-NOT: store volatile i8 addrspace(1)* [[STACK]],
; CHECK: [[FIELDVAL:%[^ ]+]] = load i8 addrspace(1)*,
; CHECK: store volatile i8 addrspace(1)* [[FIELDVAL]],
; CHECK: call void @cjw_root_frame_push
; CHECK: call void @write(i8 addrspace(1)* sret(i8) [[STACK]])
; CHECK: [[RELOAD:%[^ ]+]] = load volatile i8 addrspace(1)*
; CHECK: [[NOW:%[^ ]+]] = load i8 addrspace(1)*
; CHECK: icmp eq i8 addrspace(1)* [[NOW]], [[FIELDVAL]]
; CHECK: select i1 {{.*}}, i8 addrspace(1)* [[RELOAD]], i8 addrspace(1)* [[NOW]]
; CHECK: call void @cjw_root_frame_pop
define void @ref_stack() {
  %s = call i8 addrspace(1)* @llvm.cj.alloca.generic(i8* bitcast (%TypeInfo* @Record.ti to i8*), i32 4), !TrustedSize !1
  call void @write(i8 addrspace(1)* sret(i8) %s)
  ret void
}

; Only the first field is read on a successor. The second reference is
; overwritten before it can be observed; the container address never escapes.
%Two = type { i8 addrspace(1)*, i8 addrspace(1)* }
@Pair.ti = external global %TypeInfo, !RelatedType !4
; CHECK-LABEL: define i8 addrspace(1)* @one_live_field(
; CHECK: alloca { i8*, i8*, i32, [1 x i8 addrspace(1)*] }
; CHECK: store volatile i8 addrspace(1)*
; CHECK-NOT: store volatile
; CHECK: store i32 1,
; CHECK: call void @cjw_root_frame_push
; CHECK: call void @collect()
; CHECK: call void @cjw_root_frame_pop
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

; On the unknown incoming edge the shadow base is null; the unknown pointer
; itself is retained untouched. On the other edge the original offset is
; applied to the post-call object, even when the caller uses only the join.
; CHECK-LABEL: define i8 @mixed(
; CHECK: [[BASE:%[^ ]+]] = phi i8 addrspace(1)* [ %object, %left ], [ null, %right ]
; CHECK: [[FALLBACK:%[^ ]+]] = phi i8 addrspace(1)* [ null, %left ], [ %unknown, %right ]
; CHECK: store volatile i8 addrspace(1)* [[BASE]],
; CHECK: call void @collect()
; CHECK: [[RELOAD:%[^ ]+]] = load volatile i8 addrspace(1)*
; CHECK: call void @cjw_root_frame_pop
; CHECK: [[ADDR:%[^ ]+]] = getelementptr i8, i8 addrspace(1)* [[RELOAD]], i32
; CHECK: [[MERGE:%[^ ]+]] = select i1 {{.*}}, i8 addrspace(1)* [[ADDR]], i8 addrspace(1)* [[FALLBACK]]
; CHECK: load i8, i8 addrspace(1)* [[MERGE]]
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

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"cj.wasm.root.version", i32 1}
!1 = !{}
!2 = !{!"Int64.Type"}
!3 = !{!"RefPayload"}
!4 = !{!"Two"}
