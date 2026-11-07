; Fused interface dispatch lookup: lowering, scalar C ABI and optimizer
; treatment of llvm.cj.get.mtable.func.outertype.
; REQUIRES: x86-registered-target, aarch64-registered-target
; RUN: opt -passes=cj-runtime-lowering -S < %s | FileCheck %s --check-prefix=LOWER
; RUN: opt -passes=cj-runtime-lowering -S < %s | llc -O2 -mtriple=x86_64-unknown-linux-gnu -o - | FileCheck %s --check-prefix=SYSV
; RUN: opt -passes=cj-runtime-lowering -S < %s | llc -O2 -mtriple=x86_64-apple-darwin -o - | FileCheck %s --check-prefix=SYSV
; RUN: opt -passes=cj-runtime-lowering -S < %s | llc -O2 -mtriple=x86_64-w64-windows-gnu -o - | FileCheck %s --check-prefix=WIN64
; RUN: opt -passes=cj-runtime-lowering -S < %s | llc -O2 -mtriple=aarch64-linux-ohos -o - | FileCheck %s --check-prefix=A64
; RUN: opt -passes=cj-runtime-lowering -S < %s | llc -O2 -mtriple=aarch64-apple-darwin -o - | FileCheck %s --check-prefix=A64
; RUN: opt -passes='loop-mssa(licm),gvn' -S < %s | FileCheck %s --check-prefix=OPT

declare { i8*, i8* } @llvm.cj.get.mtable.func.outertype(i8*, i8*, i64)
declare i8* @llvm.cj.get.mtable.func(i8*, i8*, i64)
declare i8* @llvm.cj.get.method.outertype(i8*, i8*, i64)
declare void @use(i8*, i8*)
declare void @unload()

; One runtime call; method pointer is the indexed load of the returned table
; (invariant_load + func_table + vfe wrapper as for the legacy mtable); outer
; TypeInfo is a plain load of the entry-block slot passed as the 4th argument.
; LOWER-LABEL: define void @lower(
; LOWER: entry:
; LOWER-NEXT: %mtable.outer.ti = alloca i8*
; LOWER: [[TBL:%.*]] = call i8* @CJ_MCC_GetMTableAndOuterTI(i8* %ti, i8* %itf, i64 3, i8** %mtable.outer.ti)
; LOWER-NEXT: [[BC:%.*]] = bitcast i8* [[TBL]] to i8**
; LOWER-NEXT: [[GEP:%.*]] = getelementptr i8*, i8** [[BC]], i64 3
; LOWER-NEXT: [[FP:%.*]] = load i8*, i8** [[GEP]], align 8, !invariant.load !{{[0-9]+}}, !func_table ![[FT:[0-9]+]]
; LOWER-NEXT: [[VFE:%.*]] = call i8* @llvm.cj.vfe.info(i8* [[FP]], metadata ![[OBJ:[0-9]+]], i64 3)
; LOWER-NEXT: [[OUT:%.*]] = load i8*, i8** %mtable.outer.ti
; LOWER-NOT: invariant.load
; LOWER-NEXT: call void @use(i8* [[VFE]], i8* [[OUT]])
; LOWER-NOT: llvm.cj.get.mtable.func.outertype
; LOWER-NOT: CJ_MCC_GetMethodOuterTI
; LOWER: ret void
define void @lower(i8* %ti, i8* %itf) {
entry:
  %r = call { i8*, i8* } @llvm.cj.get.mtable.func.outertype(i8* %ti, i8* %itf, i64 3), !obj_type !0
  %fp = extractvalue { i8*, i8* } %r, 0
  %outer = extractvalue { i8*, i8* } %r, 1
  call void @use(i8* %fp, i8* %outer)
  ret void
}

; Scalar pointer return and four scalar register arguments; no hidden sret on
; any supported target.
; LOWER: declare i8* @CJ_MCC_GetMTableAndOuterTI(i8*, i8*, i64, i8**)
; LOWER-NOT: sret
; SYSV-LABEL: {{_?}}lower:
; SYSV-DAG: movl $3, %edx
; SYSV-DAG: {{leaq|movq}} {{.*}}%rcx
; SYSV: {{callq|call}} {{_?}}CJ_MCC_GetMTableAndOuterTI
; WIN64-LABEL: lower:
; WIN64-DAG: movl $3, %r8d
; WIN64-DAG: leaq {{.*}}%r9
; WIN64: callq CJ_MCC_GetMTableAndOuterTI
; A64-LABEL: {{_?}}lower:
; A64-DAG: mov {{[wx]}}2, #3
; A64-DAG: {{add|mov}} x3, sp
; A64: bl {{_?}}CJ_MCC_GetMTableAndOuterTI

; The fused call is neither hoisted out of a loop nor merged across an opaque
; call (e.g. a library unload): each dispatch performs its own lookup.
; OPT-LABEL: define void @loop_fused(
; OPT: entry:
; OPT-NOT: llvm.cj.get.mtable.func.outertype
; OPT: loop:
; OPT: call { i8*, i8* } @llvm.cj.get.mtable.func.outertype(i8* %ti, i8* %itf, i64 2)
; OPT: br i1
define void @loop_fused(i8* %ti, i8* %itf, i64 %n) {
entry:
  br label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %i.next, %loop ]
  %r = call { i8*, i8* } @llvm.cj.get.mtable.func.outertype(i8* %ti, i8* %itf, i64 2)
  %fp = extractvalue { i8*, i8* } %r, 0
  %outer = extractvalue { i8*, i8* } %r, 1
  call void @use(i8* %fp, i8* %outer)
  %i.next = add i64 %i, 1
  %c = icmp slt i64 %i.next, %n
  br i1 %c, label %loop, label %exit
exit:
  ret void
}

; OPT-LABEL: define void @cse_fused(
; OPT: call { i8*, i8* } @llvm.cj.get.mtable.func.outertype(
; OPT: call void @unload()
; OPT: call { i8*, i8* } @llvm.cj.get.mtable.func.outertype(
define void @cse_fused(i8* %ti, i8* %itf) {
entry:
  %r0 = call { i8*, i8* } @llvm.cj.get.mtable.func.outertype(i8* %ti, i8* %itf, i64 1)
  %fp0 = extractvalue { i8*, i8* } %r0, 0
  %o0 = extractvalue { i8*, i8* } %r0, 1
  call void @use(i8* %fp0, i8* %o0)
  call void @unload()
  %r1 = call { i8*, i8* } @llvm.cj.get.mtable.func.outertype(i8* %ti, i8* %itf, i64 1)
  %fp1 = extractvalue { i8*, i8* } %r1, 0
  %o1 = extractvalue { i8*, i8* } %r1, 1
  call void @use(i8* %fp1, i8* %o1)
  ret void
}

; Baseline record (unchanged by this patch): the legacy readnone/speculatable
; pair is hoisted out of the loop and merged across the opaque call.
; OPT-LABEL: define void @loop_legacy(
; OPT: entry:
; OPT: call i8* @llvm.cj.get.mtable.func(
; OPT: call i8* @llvm.cj.get.method.outertype(
; OPT: loop:
; OPT-NOT: llvm.cj.get.m
; OPT: br i1
define void @loop_legacy(i8* %ti, i8* %itf, i64 %n) {
entry:
  br label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %i.next, %loop ]
  %fp = call i8* @llvm.cj.get.mtable.func(i8* %ti, i8* %itf, i64 2)
  %outer = call i8* @llvm.cj.get.method.outertype(i8* %ti, i8* %itf, i64 2)
  call void @use(i8* %fp, i8* %outer)
  %i.next = add i64 %i, 1
  %c = icmp slt i64 %i.next, %n
  br i1 %c, label %loop, label %exit
exit:
  ret void
}

!0 = !{!"Iface"}
