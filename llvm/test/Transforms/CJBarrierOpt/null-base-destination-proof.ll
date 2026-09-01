; RUN: opt -enable-new-pm=false --cj-barrier-opt -S < %s | FileCheck %s
; RUN: opt -passes=cj-barrier-opt -S < %s | FileCheck %s

%holder = type { i8 addrspace(1)* }

declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*,
                                  i8 addrspace(1)* addrspace(1)*)
declare void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)*, i8 addrspace(1)*,
                                          i8*, i64)

; A null base does not make a slot non-heap. The allocation result is a heap
; object even though the field pointer has no global or argument origin.
; CHECK-LABEL: define void @keep_heap_destination(
; CHECK: call void @llvm.cj.gcwrite.ref(
; CHECK-NOT: store i8 addrspace(1)* %value
; CHECK: ret void
define void @keep_heap_destination(i8 addrspace(1)* %value) gc "cangjie" {
entry:
  %object = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* null, i32 16)
  %typed = bitcast i8 addrspace(1)* %object to %holder addrspace(1)*
  %field = getelementptr inbounds %holder, %holder addrspace(1)* %typed,
                                  i64 0, i32 0
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value,
                                  i8 addrspace(1)* null,
                                  i8 addrspace(1)* addrspace(1)* %field)
  ret void
}

; An alloca is a structural non-heap proof. Preserve the existing raw stack
; store optimization even when the barrier's destination is cast to AS1.
; CHECK-LABEL: define void @lower_nonheap_destination(
; CHECK-NOT: call void @llvm.cj.gcwrite.ref(
; CHECK: store i8 addrspace(1)* %value
; CHECK-NOT: call void @llvm.cj.gcwrite.ref(
; CHECK: ret void
define void @lower_nonheap_destination(i8 addrspace(1)* %value) gc "cangjie" {
entry:
  %slot = alloca i8 addrspace(1)*, align 8
  %slot.as1 = addrspacecast i8 addrspace(1)** %slot to
                                i8 addrspace(1)* addrspace(1)*
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value,
                                  i8 addrspace(1)* null,
                                  i8 addrspace(1)* addrspace(1)* %slot.as1)
  ret void
}

; Same null-base rule for struct writes: heap dest stays a barrier.
; CHECK-LABEL: define void @keep_heap_struct_destination(
; CHECK: call void @llvm.cj.gcwrite.struct
; CHECK-NOT: call void @llvm.memcpy
; CHECK: ret void
define void @keep_heap_struct_destination(i8* %src) gc "cangjie" {
entry:
  %object = call i8 addrspace(1)* @CJ_MCC_NewObject(i8* null, i32 16)
  call void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)* null,
                                         i8 addrspace(1)* %object,
                                         i8* %src, i64 16)
  ret void
}

; AS0 alloca dest remains eligible for the raw copy.
; CHECK-LABEL: define void @lower_nonheap_struct_destination(
; CHECK-NOT: call void @llvm.cj.gcwrite.struct
; CHECK: call void @llvm.memcpy
; CHECK-NOT: call void @llvm.cj.gcwrite.struct
; CHECK: ret void
define void @lower_nonheap_struct_destination(i8* %src) gc "cangjie" {
entry:
  %slot = alloca %holder, align 8
  %slot.i8 = bitcast %holder* %slot to i8*
  %slot.as1 = addrspacecast i8* %slot.i8 to i8 addrspace(1)*
  call void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)* null,
                                         i8 addrspace(1)* %slot.as1,
                                         i8* %src, i64 8)
  ret void
}
