; RUN: opt -S -O2 < %s | FileCheck %s --check-prefix=SURVIVE
; RUN: opt -S -O2 < %s | opt -managed-abi-gate-report-only \
; RUN:   -passes=managed-abi-gate-verifier -disable-output 2>&1 | FileCheck %s --check-prefix=GATE

@.safe = private unnamed_addr constant [22 x i8] c"cj.repr.plain_safe.v1\00"

declare i8 addrspace(1)* @llvm.ptr.annotation.p1i8(
    i8 addrspace(1)*, i8*, i8*, i32, i8*)
declare "cj.repr.ret"="plain_safe" i8 addrspace(1)* @managed_result()
declare void @managed_sink(i8 addrspace(1)*)

define void @o2_survival(i8 addrspace(1)* %raw) gc "cangjie" {
; SURVIVE: call i8 addrspace(1)* @llvm.ptr.annotation.p1i8
; SURVIVE: call "cj.repr.ret"="plain_safe" i8 addrspace(1)* @managed_result()
; GATE-NOT: [MANAGED_ABI_GATE] report
; GATE: [MANAGED_ABI_GATE] summary
entry:
  %safe = call i8 addrspace(1)* @llvm.ptr.annotation.p1i8(
      i8 addrspace(1)* %raw,
      i8* getelementptr inbounds ([22 x i8], [22 x i8]* @.safe, i64 0, i64 0),
      i8* null, i32 0, i8* null)
  %contracted = call "cj.repr.ret"="plain_safe" i8 addrspace(1)* @managed_result()
  call void @managed_sink(i8 addrspace(1)* %safe)
  call void @managed_sink(i8 addrspace(1)* %contracted)
  ret void
}
