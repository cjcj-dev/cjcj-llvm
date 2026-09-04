; RUN: rm -f %t.env.tsv %t.cli.tsv %t.concurrent.tsv
; RUN: not --crash opt -passes=cj-ir-verifier -disable-output %s 2>&1 | FileCheck %s --check-prefix=STRICT
; RUN: env CJ_IR_VERIFIER_MODE=report CJ_IR_VERIFIER_REPORT=%t.env.tsv opt -passes=cj-ir-verifier -S %s -o %t.env.ll
; RUN: cat %t.env.tsv | count 4
; RUN: tail -n +2 %t.env.tsv | count 3
; RUN: FileCheck %s --check-prefix=REPORT < %t.env.tsv
; RUN: FileCheck %s --check-prefix=IR < %t.env.ll
; RUN: opt -S %s -o %t.base.ll
; RUN: %python -c "import sys; a=open(r'%t.base.ll','rb').read(); b=open(r'%t.env.ll','rb').read(); i=b.index(b'\n!cj.verifier.mode = '); sys.exit(0 if a == b[:i] else 1)"
; RUN: env CJ_IR_VERIFIER_REPORT=%t.cli.tsv opt -cj-ir-verifier-mode=report -passes=cj-ir-verifier -disable-output %s
; RUN: cmp %t.env.tsv %t.cli.tsv
; RUN: env CJ_IR_VERIFIER_MODE=report CJ_IR_VERIFIER_REPORT=%t.concurrent.tsv opt -passes=cj-ir-verifier -disable-output %s & env CJ_IR_VERIFIER_MODE=report CJ_IR_VERIFIER_REPORT=%t.concurrent.tsv opt -passes=cj-ir-verifier -disable-output %s & wait
; RUN: %python -c "p=r'%t.concurrent.tsv'; h=b'module\tfunction\trule\tinstruction\tdest_as\tsrc_as\tlength\tdest_root\tsrc_root\tsource_type'; x=open(p,'rb').read().splitlines(); assert len(x)==7 and x.count(h)==1 and all(len(r.split(b'\t'))==10 for r in x)"
; RUN: env CJ_IR_VERIFIER_MODE=report opt -passes=cj-ir-verifier -disable-output %s 2>&1 | FileCheck %s --check-prefix=REPORT

; STRICT: Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.
; STRICT: in function reject_memcpy
; STRICT: LLVM ERROR: Broken function found, compilation aborted!
; STRICT-NOT: reject_memmove

; REPORT: module{{[[:space:]]}}function{{[[:space:]]}}rule{{[[:space:]]}}instruction{{[[:space:]]}}dest_as{{[[:space:]]}}src_as{{[[:space:]]}}length{{[[:space:]]}}dest_root{{[[:space:]]}}src_root{{[[:space:]]}}source_type
; REPORT-NEXT: report-mode.ll{{[[:space:]]}}reject_memcpy{{[[:space:]]}}Bare memcpy/memmove of reference payload must use cj_array_copy_ref or another typed GC barrier.{{[[:space:]]}}memcpy{{[[:space:]]}}0{{[[:space:]]}}0{{[[:space:]]}}8{{[[:space:]]}}alloca{{[[:space:]]}}alloca{{[[:space:]]}}%Payload*
; REPORT-NEXT: report-mode.ll{{[[:space:]]}}reject_memmove_and_addrspacecast{{[[:space:]]}}Bare memcpy/memmove payload provenance is unknown; use cj_array_copy_ref, a typed helper, or supply typed provenance.{{[[:space:]]}}memmove{{[[:space:]]}}0{{[[:space:]]}}1{{[[:space:]]}}8{{[[:space:]]}}alloca{{[[:space:]]}}argument{{[[:space:]]}}i8 addrspace(1)*
; REPORT-NEXT: report-mode.ll{{[[:space:]]}}reject_memmove_and_addrspacecast{{[[:space:]]}}AddrSpaceCast source must be addrspace(0){{[[:space:]]}}addrspacecast{{[[:space:]]}}0{{[[:space:]]}}1{{[[:space:]]}}-{{[[:space:]]}}argument{{[[:space:]]}}argument{{[[:space:]]}}%Obj addrspace(1)*

; IR: !cj.verifier.mode = !{![[MODE:[0-9]+]]}
; IR: ![[MODE]] = !{!"report"}

source_filename = "report-mode.ll"
target datalayout = "e-p:64:64-p1:64:64"

%Obj = type { i64 }
%Payload = type { i8 addrspace(1)*, i8 addrspace(1)* }

define void @reject_memcpy() gc "cangjie" {
entry:
  %dst = alloca %Payload, align 8
  %src = alloca %Payload, align 8
  %dst.i8 = bitcast %Payload* %dst to i8*
  %src.i8 = bitcast %Payload* %src to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 16, i1 false)
  call void @llvm.cj.memset(i8* %src.i8, i8 0, i64 16, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.i8, i8* %src.i8, i64 8,
                                       i1 false)
  ret void
}

define void @reject_memmove_and_addrspacecast(
    i8 addrspace(1)* %src, i8 addrspace(1)* %object) gc "cangjie" {
entry:
  %dst = alloca [8 x i8], align 8
  %dst.i8 = bitcast [8 x i8]* %dst to i8*
  call void @llvm.memmove.p0i8.p1i8.i64(i8* %dst.i8, i8 addrspace(1)* %src, i64 8, i1 false)
  %obj = bitcast i8 addrspace(1)* %object to %Obj addrspace(1)*
  %native = addrspacecast %Obj addrspace(1)* %obj to %Obj*
  call void @consume(%Obj* %native)
  ret void
}

declare void @consume(%Obj*)
declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
declare void @llvm.memcpy.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
declare void @llvm.memmove.p0i8.p1i8.i64(i8*, i8 addrspace(1)*, i64, i1)
