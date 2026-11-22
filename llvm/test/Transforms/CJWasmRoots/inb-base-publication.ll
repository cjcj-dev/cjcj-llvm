; RUN: opt -passes=cj-wasm-roots,verify -S %s | FileCheck %s
; RUN: sed -e 's/^; ERR-NODOM://' %s > %t.nodom.ll
; RUN: not opt -passes=cj-wasm-roots -disable-output %t.nodom.ll 2>&1 \
; RUN:   | FileCheck %s --check-prefix=NODOM
target datalayout = "e-m:e-p:32:32-p1:32:32-i64:64-n32:64-S128-ni:1"
target triple = "wasm32-unknown-wasi"

; A merged derived reference with a non-inbounds leaf is published at a call
; that may collect, but the object it was derived from has no other use, so it
; is not live there. Its base is an object start dominating the call: publish
; the base so the object stays alive (I-INB).

declare i8 addrspace(1)* @get()
declare void @collect()
declare void @use(i8 addrspace(1)*)

; LinkedList.removeLast at -O2: a select of two field addresses of one object.
; CHECK-LABEL: define void @select_base(
; CHECK: %o = call i8 addrspace(1)* @get()
; CHECK: %s = select
; CHECK: store i8 addrspace(1)* %o,
; CHECK: call void @collect()
define void @select_base(i1 %c) {
entry:
  %o = call i8 addrspace(1)* @get()
  %f12 = getelementptr i8, i8 addrspace(1)* %o, i32 12
  %f16 = getelementptr i8, i8 addrspace(1)* %o, i32 16
  %s = select i1 %c, i8 addrspace(1)* %f16, i8 addrspace(1)* %f12
  call void @collect()
  call void @use(i8 addrspace(1)* %s)
  ret void
}

; StringReader.readlnFromBuf at -O2: a GVN PRE phi of a strength-reduced
; (non-inbounds) address and an inbounds one, both into the same object.
; CHECK-LABEL: define void @phi_base(
; CHECK: %o = call i8 addrspace(1)* @get()
; CHECK: j:
; CHECK: store i8 addrspace(1)* %o,
; CHECK: call void @collect()
define void @phi_base(i1 %c, i32 %n) {
entry:
  %o = call i8 addrspace(1)* @get()
  br i1 %c, label %l, label %r
l:
  %x = getelementptr i8, i8 addrspace(1)* %o, i32 %n
  br label %j
r:
  %y = getelementptr inbounds i8, i8 addrspace(1)* %o, i32 8
  br label %j
j:
  %p = phi i8 addrspace(1)* [ %x, %l ], [ %y, %r ]
  call void @collect()
  call void @use(i8 addrspace(1)* %p)
  ret void
}

; The base is the receiver: published as well (I-CARG already keeps it alive).
; CHECK-LABEL: define void @arg_base(
; CHECK: j:
; CHECK: store i8 addrspace(1)* %this,
; CHECK: call void @collect()
define void @arg_base(i8 addrspace(1)* %this, i1 %c) {
entry:
  br i1 %c, label %l, label %r
l:
  %x = getelementptr i8, i8 addrspace(1)* %this, i32 4
  br label %j
r:
  %y = getelementptr inbounds i8, i8 addrspace(1)* %this, i32 8
  br label %j
j:
  %p = phi i8 addrspace(1)* [ %x, %l ], [ %y, %r ]
  call void @collect()
  call void @use(i8 addrspace(1)* %p)
  ret void
}

; A base that does not dominate the call cannot be published there: still a
; compile error, never an unpublished live object.
; ERR-NODOM:define void @nodom(i1 %c, i8 addrspace(1)* %b) {
; ERR-NODOM:entry:
; ERR-NODOM:  br i1 %c, label %l, label %j
; ERR-NODOM:l:
; ERR-NODOM:  %o = call i8 addrspace(1)* @get()
; ERR-NODOM:  %x = getelementptr i8, i8 addrspace(1)* %o, i32 100000
; ERR-NODOM:  br label %j
; ERR-NODOM:j:
; ERR-NODOM:  %p = phi i8 addrspace(1)* [ %x, %l ], [ %b, %entry ]
; ERR-NODOM:  call void @collect()
; ERR-NODOM:  call void @use(i8 addrspace(1)* %p)
; ERR-NODOM:  ret void
; ERR-NODOM:}
; NODOM: error: unsupported WASI root publication in nodom: merged derived reference p has a non-inbounds or inttoptr incoming whose base is not live (I-INB)
