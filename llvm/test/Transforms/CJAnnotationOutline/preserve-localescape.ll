; RUN: opt -passes=cj-annotation-outline -verify-each -S %s | FileCheck %s
;
; Preserve the original escape table and its external recover consumer.
; Ordinary local allocations without a function-bound escape still outline.

declare void @llvm.localescape(...)
declare i8* @llvm.localrecover(i8*, i8*, i32 immarg)
declare i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** nocapture)
declare void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)*, i8 addrspace(1)**)
@slotA = internal global i8 addrspace(1)* null
@slotB = internal global i8 addrspace(1)* null
@output = internal global i8 addrspace(1)* null

; CHECK-LABEL: define void @_CAFescapeA()
; CHECK-NOT: _imp(
; CHECK: %local = alloca i8, align 1
; CHECK-NEXT: call void (...) @llvm.localescape(i8* %local)
; CHECK: store i8 7, i8* %local, align 1
; CHECK-NEXT: ret void
define void @_CAFescapeA() gc "cangjie" {
entry:
  %local = alloca i8, align 1
  call void (...) @llvm.localescape(i8* %local)
  %ref = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @slotA)
  call void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)* %ref, i8 addrspace(1)** @output)
  store i8 7, i8* %local, align 1
  ret void
}

; CHECK-LABEL: define void @_CAFescapeB()
; CHECK-NOT: _imp(
; CHECK: %local = alloca i8, align 1
; CHECK-NEXT: call void (...) @llvm.localescape(i8* %local)
; CHECK: store i8 7, i8* %local, align 1
; CHECK-NEXT: ret void
define void @_CAFescapeB() gc "cangjie" {
entry:
  %local = alloca i8, align 1
  call void (...) @llvm.localescape(i8* %local)
  %ref = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @slotB)
  call void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)* %ref, i8 addrspace(1)** @output)
  store i8 7, i8* %local, align 1
  ret void
}

; CHECK-LABEL: define i8* @recoverA
; CHECK: call i8* @llvm.localrecover(i8* bitcast (void ()* @_CAFescapeA to i8*), i8* %liveParentFrame, i32 0)
; CHECK-NEXT: ret i8* %local
define i8* @recoverA(i8* %liveParentFrame) {
entry:
  %local = call i8* @llvm.localrecover(i8* bitcast (void ()* @_CAFescapeA to i8*), i8* %liveParentFrame, i32 0)
  ret i8* %local
}

; CHECK-LABEL: define void @_CAFordinaryA()
; CHECK: call void @_CAFordinaryA_imp(i8 addrspace(1)** @slotA)
; CHECK-NEXT: ret void
define void @_CAFordinaryA() gc "cangjie" {
entry:
  %local = alloca i8, align 1
  %ref = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @slotA)
  call void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)* %ref, i8 addrspace(1)** @output)
  store volatile i8 7, i8* %local, align 1
  store volatile i8 8, i8* %local, align 1
  ret void
}

; CHECK-LABEL: define void @_CAFordinaryB()
; CHECK: call void @_CAFordinaryA_imp(i8 addrspace(1)** @slotB)
; CHECK-NEXT: ret void
define void @_CAFordinaryB() gc "cangjie" {
entry:
  %local = alloca i8, align 1
  %ref = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @slotB)
  call void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)* %ref, i8 addrspace(1)** @output)
  store volatile i8 7, i8* %local, align 1
  store volatile i8 8, i8* %local, align 1
  ret void
}

; CHECK-LABEL: define internal void @_CAFordinaryA_imp(i8 addrspace(1)** %slot0) local_unnamed_addr
; CHECK: %[[LOCAL:.*]] = alloca i8, align 1
; CHECK: call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** %slot0)
; CHECK: store volatile i8 7, i8* %[[LOCAL]], align 1
; CHECK-NEXT: store volatile i8 8, i8* %[[LOCAL]], align 1
; CHECK-NEXT: ret void
