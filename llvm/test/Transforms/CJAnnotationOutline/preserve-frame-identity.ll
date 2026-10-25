; RUN: opt -passes=cj-annotation-outline -verify-each -S %s | FileCheck %s
;
; A helper would observe its own frame instead of the original factory's.
; Each pair has identical full contracts and a profitable shared body.

@slotA = internal global i8 addrspace(1)* null
@slotB = internal global i8 addrspace(1)* null
@output = internal global i8 addrspace(1)* null
@observed = internal global i8* null
@counter = internal global i32 0
declare i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** nocapture)
declare void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)*, i8 addrspace(1)**)
declare i8* @llvm.frameaddress.p0i8(i32 immarg)
declare i8* @llvm.returnaddress(i32 immarg)
declare i8* @llvm.addressofreturnaddress.p0i8()
declare i8* @llvm.sponentry.p0i8()
declare i8* @llvm.localaddress()
declare i8* @llvm.eh.dwarf.cfa(i32)

; CHECK-LABEL: define void @_CAFframeA()
; CHECK-NOT: _imp(
; CHECK: %address = call i8* @llvm.frameaddress.p0i8(i32 0)
; CHECK-NEXT: store volatile i8* %address, i8** @observed
; CHECK: store volatile i32 1, i32* @counter
; CHECK-NEXT: ret void
define void @_CAFframeA() gc "cangjie" {
entry:
  %address = call i8* @llvm.frameaddress.p0i8(i32 0)
  store volatile i8* %address, i8** @observed
  %ref = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @slotA)
  call void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)* %ref, i8 addrspace(1)** @output)
  store volatile i32 1, i32* @counter
  ret void
}

; CHECK-LABEL: define void @_CAFframeB()
; CHECK-NOT: _imp(
; CHECK: %address = call i8* @llvm.frameaddress.p0i8(i32 0)
; CHECK-NEXT: store volatile i8* %address, i8** @observed
; CHECK: store volatile i32 1, i32* @counter
; CHECK-NEXT: ret void
define void @_CAFframeB() gc "cangjie" {
entry:
  %address = call i8* @llvm.frameaddress.p0i8(i32 0)
  store volatile i8* %address, i8** @observed
  %ref = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @slotB)
  call void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)* %ref, i8 addrspace(1)** @output)
  store volatile i32 1, i32* @counter
  ret void
}

; CHECK-LABEL: define void @_CAFreturnA()
; CHECK-NOT: _imp(
; CHECK: %address = call i8* @llvm.returnaddress(i32 0)
; CHECK-NEXT: store volatile i8* %address, i8** @observed
; CHECK: store volatile i32 1, i32* @counter
; CHECK-NEXT: ret void
define void @_CAFreturnA() gc "cangjie" {
entry:
  %address = call i8* @llvm.returnaddress(i32 0)
  store volatile i8* %address, i8** @observed
  %ref = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @slotA)
  call void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)* %ref, i8 addrspace(1)** @output)
  store volatile i32 1, i32* @counter
  ret void
}

; CHECK-LABEL: define void @_CAFreturnB()
; CHECK-NOT: _imp(
; CHECK: %address = call i8* @llvm.returnaddress(i32 0)
; CHECK-NEXT: store volatile i8* %address, i8** @observed
; CHECK: store volatile i32 1, i32* @counter
; CHECK-NEXT: ret void
define void @_CAFreturnB() gc "cangjie" {
entry:
  %address = call i8* @llvm.returnaddress(i32 0)
  store volatile i8* %address, i8** @observed
  %ref = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @slotB)
  call void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)* %ref, i8 addrspace(1)** @output)
  store volatile i32 1, i32* @counter
  ret void
}

; CHECK-LABEL: define void @_CAFreturnslotA()
; CHECK-NOT: _imp(
; CHECK: %address = call i8* @llvm.addressofreturnaddress.p0i8()
; CHECK-NEXT: store volatile i8* %address, i8** @observed
; CHECK: store volatile i32 1, i32* @counter
; CHECK-NEXT: ret void
define void @_CAFreturnslotA() gc "cangjie" {
entry:
  %address = call i8* @llvm.addressofreturnaddress.p0i8()
  store volatile i8* %address, i8** @observed
  %ref = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @slotA)
  call void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)* %ref, i8 addrspace(1)** @output)
  store volatile i32 1, i32* @counter
  ret void
}

; CHECK-LABEL: define void @_CAFreturnslotB()
; CHECK-NOT: _imp(
; CHECK: %address = call i8* @llvm.addressofreturnaddress.p0i8()
; CHECK-NEXT: store volatile i8* %address, i8** @observed
; CHECK: store volatile i32 1, i32* @counter
; CHECK-NEXT: ret void
define void @_CAFreturnslotB() gc "cangjie" {
entry:
  %address = call i8* @llvm.addressofreturnaddress.p0i8()
  store volatile i8* %address, i8** @observed
  %ref = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @slotB)
  call void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)* %ref, i8 addrspace(1)** @output)
  store volatile i32 1, i32* @counter
  ret void
}

; CHECK-LABEL: define void @_CAFentryspA()
; CHECK-NOT: _imp(
; CHECK: %address = call i8* @llvm.sponentry.p0i8()
; CHECK-NEXT: store volatile i8* %address, i8** @observed
; CHECK: store volatile i32 1, i32* @counter
; CHECK-NEXT: ret void
define void @_CAFentryspA() gc "cangjie" {
entry:
  %address = call i8* @llvm.sponentry.p0i8()
  store volatile i8* %address, i8** @observed
  %ref = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @slotA)
  call void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)* %ref, i8 addrspace(1)** @output)
  store volatile i32 1, i32* @counter
  ret void
}

; CHECK-LABEL: define void @_CAFentryspB()
; CHECK-NOT: _imp(
; CHECK: %address = call i8* @llvm.sponentry.p0i8()
; CHECK-NEXT: store volatile i8* %address, i8** @observed
; CHECK: store volatile i32 1, i32* @counter
; CHECK-NEXT: ret void
define void @_CAFentryspB() gc "cangjie" {
entry:
  %address = call i8* @llvm.sponentry.p0i8()
  store volatile i8* %address, i8** @observed
  %ref = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @slotB)
  call void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)* %ref, i8 addrspace(1)** @output)
  store volatile i32 1, i32* @counter
  ret void
}

; CHECK-LABEL: define void @_CAFlocalA()
; CHECK-NOT: _imp(
; CHECK: %address = call i8* @llvm.localaddress()
; CHECK-NEXT: store volatile i8* %address, i8** @observed
; CHECK: store volatile i32 1, i32* @counter
; CHECK-NEXT: ret void
define void @_CAFlocalA() gc "cangjie" {
entry:
  %address = call i8* @llvm.localaddress()
  store volatile i8* %address, i8** @observed
  %ref = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @slotA)
  call void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)* %ref, i8 addrspace(1)** @output)
  store volatile i32 1, i32* @counter
  ret void
}

; CHECK-LABEL: define void @_CAFlocalB()
; CHECK-NOT: _imp(
; CHECK: %address = call i8* @llvm.localaddress()
; CHECK-NEXT: store volatile i8* %address, i8** @observed
; CHECK: store volatile i32 1, i32* @counter
; CHECK-NEXT: ret void
define void @_CAFlocalB() gc "cangjie" {
entry:
  %address = call i8* @llvm.localaddress()
  store volatile i8* %address, i8** @observed
  %ref = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @slotB)
  call void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)* %ref, i8 addrspace(1)** @output)
  store volatile i32 1, i32* @counter
  ret void
}

; CHECK-LABEL: define void @_CAFcfaA()
; CHECK-NOT: _imp(
; CHECK: %address = call i8* @llvm.eh.dwarf.cfa(i32 0)
; CHECK-NEXT: store volatile i8* %address, i8** @observed
; CHECK: store volatile i32 1, i32* @counter
; CHECK-NEXT: ret void
define void @_CAFcfaA() gc "cangjie" {
entry:
  %address = call i8* @llvm.eh.dwarf.cfa(i32 0)
  store volatile i8* %address, i8** @observed
  %ref = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @slotA)
  call void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)* %ref, i8 addrspace(1)** @output)
  store volatile i32 1, i32* @counter
  ret void
}

; CHECK-LABEL: define void @_CAFcfaB()
; CHECK-NOT: _imp(
; CHECK: %address = call i8* @llvm.eh.dwarf.cfa(i32 0)
; CHECK-NEXT: store volatile i8* %address, i8** @observed
; CHECK: store volatile i32 1, i32* @counter
; CHECK-NEXT: ret void
define void @_CAFcfaB() gc "cangjie" {
entry:
  %address = call i8* @llvm.eh.dwarf.cfa(i32 0)
  store volatile i8* %address, i8** @observed
  %ref = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @slotB)
  call void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)* %ref, i8 addrspace(1)** @output)
  store volatile i32 1, i32* @counter
  ret void
}
