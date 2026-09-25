; RUN: not --crash opt -passes=cj-ir-verifier -disable-output < %s 2>&1 | FileCheck %s --check-prefix=VERIFY
; RUN: llc -mtriple=x86_64 -O0 -enable-gc-fast-path=false -o /dev/null < %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O0 -enable-gc-fast-path=false -o /dev/null < %s
; VERIFY: Missing cj.memset in allocation of structure.
target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
%Plain = type { i8 addrspace(1)* }
define i8 addrspace(1)* @probe(i8* %type, i8 addrspace(1)* %value, i64* %alias, i64 %word) gc "cangjie" {
entry:
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i32)* @CJ_MCC_NewObject, i32 2, i32 0, i8* %type, i32 64)
  %heap = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
  %plain = alloca %Plain
  %slot = addrspacecast %Plain* %plain to i8 addrspace(1)* addrspace(1)*
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* %heap, i8 addrspace(1)* addrspace(1)* %slot, i32 1)
  store volatile i64 %word, i64* %alias
  %result = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %heap, i8 addrspace(1)* addrspace(1)* %slot)
  ret i8 addrspace(1)* %result
}
declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare token @llvm.cj.gc.statepoint(...)
declare i8 addrspace(1)* @llvm.cj.gc.result(token)
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)
declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)

declare void @llvm.cj.memset(i8*, i8, i64, i1)
