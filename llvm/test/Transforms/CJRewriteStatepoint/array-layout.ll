; RUN: opt -passes=cj-rewrite-statepoint -S < %s | FileCheck %s

target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"

%Nested = type { [2 x [2 x i8 addrspace(1)*]] }
%Mixed = type { i8 addrspace(1)*, [2 x i8*] }

declare void @safepoint()

; CHECK-LABEL: define i8 addrspace(1)* @nested_array_last
; CHECK: call token (...) @llvm.cj.gc.statepoint{{.*}}@safepoint{{.*}}[ "struct-live"(i8* %field) ]
define i8 addrspace(1)* @nested_array_last() gc "cangjie" {
entry:
  %nested = alloca %Nested, align 8
  %last = getelementptr inbounds %Nested, %Nested* %nested, i64 0, i32 0, i64 1, i64 1
  call void @safepoint()
  %value = load i8 addrspace(1)*, i8 addrspace(1)** %last, align 8
  ret i8 addrspace(1)* %value
}

; CHECK-LABEL: define i8* @native_array_last
; CHECK: call token (...) @llvm.cj.gc.statepoint{{.*}}@safepoint
; CHECK-NOT: struct-live
; CHECK: ret i8*
define i8* @native_array_last() gc "cangjie" {
entry:
  %mixed = alloca %Mixed, align 8
  %last = getelementptr inbounds %Mixed, %Mixed* %mixed, i64 0, i32 1, i64 1
  call void @safepoint()
  %value = load i8*, i8** %last, align 8
  ret i8* %value
}
