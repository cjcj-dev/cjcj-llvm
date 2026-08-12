; RUN: opt -passes=cj-rewrite-statepoint -S < %s | FileCheck %s

target datalayout = "e-m:e-p:32:32-p1:32:32-i64:64-n8:16:32-S128"

%Flat = type { [2 x i8 addrspace(1)*] }

declare void @safepoint()

; CHECK-LABEL: define i8 addrspace(1)* @array_second_ptr32
; CHECK: call token (...) @llvm.cj.gc.statepoint{{.*}}@safepoint{{.*}}[ "struct-live"(i8* %field) ]
define i8 addrspace(1)* @array_second_ptr32() gc "cangjie" {
entry:
  %flat = alloca %Flat, align 4
  %second = getelementptr inbounds %Flat, %Flat* %flat, i32 0, i32 0, i32 1
  call void @safepoint()
  %value = load i8 addrspace(1)*, i8 addrspace(1)** %second, align 4
  ret i8 addrspace(1)* %value
}
