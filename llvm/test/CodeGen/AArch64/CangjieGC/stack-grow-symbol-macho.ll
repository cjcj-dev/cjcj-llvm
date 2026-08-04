; RUN: llc -O0 --cangjie-pipeline -disable-debug-info-print --relocation-model=pic --frame-pointer=non-leaf --stack-trace-format=default -mcpu=generic --cj-safepoint-outline=false -mtriple=arm64-apple-darwin < %s | FileCheck %s --check-prefix=DARWIN
; RUN: llc -O0 --cangjie-pipeline -disable-debug-info-print --relocation-model=pic --frame-pointer=non-leaf --stack-trace-format=default -mcpu=generic --cj-safepoint-outline=false -mtriple=aarch64-unknown-linux-gnu < %s | FileCheck %s --check-prefix=ELF

%Unit.Type = type { i8 }
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i32*, i8*, i8*, i8*, %TypeInfo*, i8*, i8* }
%BitMap = type { i32, [0 x i8] }
%string = type { %record, i64 }
%record = type { i8 addrspace(1)*, i64, i64 }

declare void @cj_stack_grow()

define internal void @stack_check(%record* nocapture sret(%record) %0, i8 addrspace(1)* nocapture %1, %TypeInfo* nocapture %2, %string* %3, i64 %4, <2 x i64> %5, void (%Unit.Type*, i8 addrspace(1)*, %record*)* %6) "leaf-function" gc "cangjie" {
entry:
  %token = call cangjiegccc token (...) @llvm.cj.gc.statepoint(i64 5, i32 0, void ()* @CJ_MCC_StackCheck, i32 0, i32 0)
  %7 = alloca %record, align 8
  %sroa = getelementptr inbounds %record, %record* %7, i64 0, i32 1
  %8 = bitcast i64* %sroa to <2 x i64>*
  store <2 x i64> %5, <2 x i64>* %8, align 8
  br label %body

body:
  %r.cast = bitcast %record* %7 to i8*
  %token1 = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, void ()* @cj_stack_grow, i32 0, i32 0)
  call void @llvm.memset.p0i8.i64(i8* nonnull align 8 %r.cast, i8 0, i64 16, i1 false)
  ret void
}

declare void @llvm.memset.p0i8.i64(i8* nocapture writeonly, i8, i64, i1 immarg)
declare void @CJ_MCC_StackCheck()
declare token @llvm.cj.gc.statepoint(...)

; DARWIN: bl _CJ_MCC_StackGrowStub
; DARWIN-NOT: bl CJ_MCC_StackGrowStub
; ELF: bl CJ_MCC_StackGrowStub
; ELF-NOT: bl _CJ_MCC_StackGrowStub
