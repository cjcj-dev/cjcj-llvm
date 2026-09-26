; RUN: llc -mtriple=x86_64 -O0 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s --check-prefix=WIDE
; RUN: llc -mtriple=x86_64 -O1 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s --check-prefix=WIDE
; RUN: llc -mtriple=x86_64 -O2 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s --check-prefix=WIDE
; RUN: llc -mtriple=i386 -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s --check-prefix=NARROW

; The runtime ABI consumes size_t, while the intrinsic consumes unsigned i32.

; WIDE-LABEL: define void @read_forward(
; WIDE: %[[S:.*]] = zext i32 %size to i64
; WIDE: call void @CJ_MCC_ReadGenericPayload(i8* %dst, i8 addrspace(1)* %obj, i64 %[[S]])
; NARROW-LABEL: define void @read_forward(
; NARROW-NOT: zext
; NARROW: call void @CJ_MCC_ReadGenericPayload(i8* %dst, i8 addrspace(1)* %obj, i32 %size)
define void @read_forward(i8* %dst, i8 addrspace(1)* %obj, i32 %size) #0 gc "cangjie" {
  call void @llvm.cj.gcread.generic.payload(i8* %dst, i8 addrspace(1)* %obj, i32 %size)
  ret void
}

; WIDE-LABEL: define void @read_load(
; WIDE: %[[S:.*]] = zext i32 %size to i64
; WIDE: call void @CJ_MCC_ReadGenericPayload(i8* %dst, i8 addrspace(1)* %obj, i64 %[[S]])
; NARROW-LABEL: define void @read_load(
; NARROW-NOT: zext
; NARROW: call void @CJ_MCC_ReadGenericPayload(i8* %dst, i8 addrspace(1)* %obj, i32 %size)
define void @read_load(i8* %dst, i8 addrspace(1)* %obj, i32* %p) #0 gc "cangjie" {
  %size = load i32, i32* %p
  call void @llvm.cj.gcread.generic.payload(i8* %dst, i8 addrspace(1)* %obj, i32 %size)
  ret void
}

; WIDE-LABEL: define void @read_high(
; WIDE: call void @CJ_MCC_ReadGenericPayload(i8* %dst, i8 addrspace(1)* %obj, i64 2147483648)
; NARROW-LABEL: define void @read_high(
; NARROW-NOT: zext
; NARROW: call void @CJ_MCC_ReadGenericPayload(i8* %dst, i8 addrspace(1)* %obj, i32 -2147483648)
define void @read_high(i8* %dst, i8 addrspace(1)* %obj) #0 gc "cangjie" {
  call void @llvm.cj.gcread.generic.payload(i8* %dst, i8 addrspace(1)* %obj, i32 -2147483648)
  ret void
}

; WIDE-LABEL: define void @write_forward(
; WIDE: %[[S:.*]] = zext i32 %size to i64
; WIDE: call void @CJ_MCC_WriteGenericPayload(i8 addrspace(1)* %obj, i8* %dst, i64 %[[S]])
; NARROW-LABEL: define void @write_forward(
; NARROW-NOT: zext
; NARROW: call void @CJ_MCC_WriteGenericPayload(i8 addrspace(1)* %obj, i8* %dst, i32 %size)
define void @write_forward(i8 addrspace(1)* %obj, i8* %dst, i32 %size) #0 gc "cangjie" {
  call void @llvm.cj.gcwrite.generic.payload(i8 addrspace(1)* %obj, i8* %dst, i32 %size)
  ret void
}

; WIDE-LABEL: define void @write_load(
; WIDE: %[[S:.*]] = zext i32 %size to i64
; WIDE: call void @CJ_MCC_WriteGenericPayload(i8 addrspace(1)* %obj, i8* %dst, i64 %[[S]])
; NARROW-LABEL: define void @write_load(
; NARROW-NOT: zext
; NARROW: call void @CJ_MCC_WriteGenericPayload(i8 addrspace(1)* %obj, i8* %dst, i32 %size)
define void @write_load(i8 addrspace(1)* %obj, i8* %dst, i32* %p) #0 gc "cangjie" {
  %size = load i32, i32* %p
  call void @llvm.cj.gcwrite.generic.payload(i8 addrspace(1)* %obj, i8* %dst, i32 %size)
  ret void
}

; WIDE-LABEL: define void @write_high(
; WIDE: call void @CJ_MCC_WriteGenericPayload(i8 addrspace(1)* %obj, i8* %dst, i64 2147483648)
; NARROW-LABEL: define void @write_high(
; NARROW-NOT: zext
; NARROW: call void @CJ_MCC_WriteGenericPayload(i8 addrspace(1)* %obj, i8* %dst, i32 -2147483648)
define void @write_high(i8 addrspace(1)* %obj, i8* %dst) #0 gc "cangjie" {
  call void @llvm.cj.gcwrite.generic.payload(i8 addrspace(1)* %obj, i8* %dst, i32 -2147483648)
  ret void
}

declare void @llvm.cj.gcread.generic.payload(i8*, i8 addrspace(1)*, i32)
declare void @llvm.cj.gcwrite.generic.payload(i8 addrspace(1)*, i8*, i32)
attributes #0 = { "leaf-function" }
