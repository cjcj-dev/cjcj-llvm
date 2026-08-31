; RUN: not not opt -passes=cj-ir-verifier < %s -disable-output 2>&1 | FileCheck %s -check-prefixes=CHECK,ABORT

%record = type { i64, i8 addrspace(1)* }

; CHECK: gcwrite/gcread.static.struct has no Metadata.
; CHECK-NEXT: call void @llvm.cj.gcwrite.static.struct.i64(i8* bitcast (%record* @record_global0 to i8*), i8* %0, i64 16)
; CHECK-NEXT: in function foo

@"record_global0" = internal global %record zeroinitializer

define void @foo() gc "cangjie" {
entry:
  %ret0 = alloca %record, align 8
  %0 = bitcast %record* %ret0 to i8*
  call void @llvm.cj.memset(i8* align 8 %0, i8 0, i64 16, i1 false)
  call void @llvm.cj.gcwrite.static.struct(i8* bitcast (%record* @"record_global0" to i8*), i8* %0, i64 16)
  ret void
}

; ABORT: LLVM ERROR: Broken function found, compilation aborted
; ABORT: error: Aborted

declare void @llvm.cj.memset(i8*, i8, i64, i1) #10

declare void @llvm.cj.gcwrite.static.struct(i8* noalias nocapture writeonly, i8* noalias nocapture readonly, i64) #9
