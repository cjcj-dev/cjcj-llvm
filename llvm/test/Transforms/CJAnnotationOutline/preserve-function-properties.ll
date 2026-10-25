; RUN: opt -passes=cj-annotation-outline -verify-each -S %s | FileCheck %s
;
; Original function addresses still own their distinct prefix/prologue and type
; metadata after outlining. Both factory and initializer paths must preserve
; that contract, while ordinary bodies continue to share helpers.

target triple = "x86_64-unknown-linux-gnu"
declare i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** nocapture)
declare void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)*, i8 addrspace(1)**)
declare i1 @llvm.type.test(i8*, metadata)
declare i32 @__gxx_personality_v0(...)
@slotA = internal global i8 addrspace(1)* null
@slotB = internal global i8 addrspace(1)* null
@source = internal global i8 addrspace(1)* null
@output = internal global i8 addrspace(1)* null

; CHECK-LABEL: define void @_CAFprefixA()
; CHECK-SAME: prefix i32 17 prologue i8 -112 personality i8* bitcast (i32 (...)* @__gxx_personality_v0 to i8*) !type ![[TYPE_FACTORY_A:[0-9]+]]
; CHECK: call void @_CAFprefixA_imp(i8 addrspace(1)** @slotA)
; CHECK-NEXT: ret void
define void @_CAFprefixA() gc "cangjie" prefix i32 17 prologue i8 -112 personality i8* bitcast (i32 (...)* @__gxx_personality_v0 to i8*) !type !0 {
entry:
  %local = alloca i8, align 1
  %ref = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @slotA)
  call void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)* %ref, i8 addrspace(1)** @output)
  store volatile i8 7, i8* %local, align 1
  store volatile i8 8, i8* %local, align 1
  ret void
}

; CHECK-LABEL: define void @_CAFprefixB()
; CHECK-SAME: prefix i32 29 prologue i8 -112 personality i8* bitcast (i32 (...)* @__gxx_personality_v0 to i8*) !type ![[TYPE_FACTORY_B:[0-9]+]]
; CHECK: call void @_CAFprefixA_imp(i8 addrspace(1)** @slotB)
; CHECK-NEXT: ret void
define void @_CAFprefixB() gc "cangjie" prefix i32 29 prologue i8 -112 personality i8* bitcast (i32 (...)* @__gxx_personality_v0 to i8*) !type !1 {
entry:
  %local = alloca i8, align 1
  %ref = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @slotB)
  call void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)* %ref, i8 addrspace(1)** @output)
  store volatile i8 7, i8* %local, align 1
  store volatile i8 8, i8* %local, align 1
  ret void
}

; CHECK-LABEL: define internal void @_CAOpropertyAiiHv()
; CHECK-SAME: prefix i32 39 prologue i8 -112 personality i8* bitcast (i32 (...)* @__gxx_personality_v0 to i8*) !type ![[TYPE_INIT_A:[0-9]+]]
; CHECK: call void @_CAOpropertyAiiHv_imp(i8 addrspace(1)** @slotA)
; CHECK-NEXT: ret void
define internal void @_CAOpropertyAiiHv() gc "cangjie" prefix i32 39 prologue i8 -112 personality i8* bitcast (i32 (...)* @__gxx_personality_v0 to i8*) !type !2 {
entry:
  %local = alloca i8, align 1
  store volatile i8 7, i8* %local, align 1
  store volatile i8 8, i8* %local, align 1
  %ref = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @source)
  call void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)* %ref, i8 addrspace(1)** @slotA)
  ret void
}

; CHECK-LABEL: define internal void @_CAOpropertyBiiHv()
; CHECK-SAME: prefix i32 53 prologue i8 -112 personality i8* bitcast (i32 (...)* @__gxx_personality_v0 to i8*) !type ![[TYPE_INIT_B:[0-9]+]]
; CHECK: call void @_CAOpropertyAiiHv_imp(i8 addrspace(1)** @slotB)
; CHECK-NEXT: ret void
define internal void @_CAOpropertyBiiHv() gc "cangjie" prefix i32 53 prologue i8 -112 personality i8* bitcast (i32 (...)* @__gxx_personality_v0 to i8*) !type !3 {
entry:
  %local = alloca i8, align 1
  store volatile i8 7, i8* %local, align 1
  store volatile i8 8, i8* %local, align 1
  %ref = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** @source)
  call void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)* %ref, i8 addrspace(1)** @slotB)
  ret void
}

; CHECK-LABEL: define i32 @readFactoryTagA()
; CHECK: %tag = getelementptr inbounds i32, i32* bitcast (void ()* @_CAFprefixA to i32*), i32 -1
; CHECK-NEXT: %value = load i32, i32* %tag, align 4
; CHECK-NEXT: ret i32 %value
define i32 @readFactoryTagA() {
entry:
  %tag = getelementptr inbounds i32, i32* bitcast (void ()* @_CAFprefixA to i32*), i32 -1
  %value = load i32, i32* %tag, align 4
  ret i32 %value
}

; CHECK-LABEL: define i1 @checkFactoryTypeA()
; CHECK: %valid = call i1 @llvm.type.test(i8* bitcast (void ()* @_CAFprefixA to i8*), metadata !"factory-A")
; CHECK-NEXT: ret i1 %valid
define i1 @checkFactoryTypeA() {
entry:
  %valid = call i1 @llvm.type.test(i8* bitcast (void ()* @_CAFprefixA to i8*), metadata !"factory-A")
  ret i1 %valid
}

; CHECK-LABEL: define i32 @readFactoryTagB()
; CHECK: %tag = getelementptr inbounds i32, i32* bitcast (void ()* @_CAFprefixB to i32*), i32 -1
; CHECK-NEXT: %value = load i32, i32* %tag, align 4
; CHECK-NEXT: ret i32 %value
define i32 @readFactoryTagB() {
entry:
  %tag = getelementptr inbounds i32, i32* bitcast (void ()* @_CAFprefixB to i32*), i32 -1
  %value = load i32, i32* %tag, align 4
  ret i32 %value
}

; CHECK-LABEL: define i1 @checkFactoryTypeB()
; CHECK: %valid = call i1 @llvm.type.test(i8* bitcast (void ()* @_CAFprefixB to i8*), metadata !"factory-B")
; CHECK-NEXT: ret i1 %valid
define i1 @checkFactoryTypeB() {
entry:
  %valid = call i1 @llvm.type.test(i8* bitcast (void ()* @_CAFprefixB to i8*), metadata !"factory-B")
  ret i1 %valid
}

; CHECK-LABEL: define i32 @readInitTagA()
; CHECK: %tag = getelementptr inbounds i32, i32* bitcast (void ()* @_CAOpropertyAiiHv to i32*), i32 -1
; CHECK-NEXT: %value = load i32, i32* %tag, align 4
; CHECK-NEXT: ret i32 %value
define i32 @readInitTagA() {
entry:
  %tag = getelementptr inbounds i32, i32* bitcast (void ()* @_CAOpropertyAiiHv to i32*), i32 -1
  %value = load i32, i32* %tag, align 4
  ret i32 %value
}

; CHECK-LABEL: define i1 @checkInitTypeA()
; CHECK: %valid = call i1 @llvm.type.test(i8* bitcast (void ()* @_CAOpropertyAiiHv to i8*), metadata !"init-A")
; CHECK-NEXT: ret i1 %valid
define i1 @checkInitTypeA() {
entry:
  %valid = call i1 @llvm.type.test(i8* bitcast (void ()* @_CAOpropertyAiiHv to i8*), metadata !"init-A")
  ret i1 %valid
}

; CHECK-LABEL: define i32 @readInitTagB()
; CHECK: %tag = getelementptr inbounds i32, i32* bitcast (void ()* @_CAOpropertyBiiHv to i32*), i32 -1
; CHECK-NEXT: %value = load i32, i32* %tag, align 4
; CHECK-NEXT: ret i32 %value
define i32 @readInitTagB() {
entry:
  %tag = getelementptr inbounds i32, i32* bitcast (void ()* @_CAOpropertyBiiHv to i32*), i32 -1
  %value = load i32, i32* %tag, align 4
  ret i32 %value
}

; CHECK-LABEL: define i1 @checkInitTypeB()
; CHECK: %valid = call i1 @llvm.type.test(i8* bitcast (void ()* @_CAOpropertyBiiHv to i8*), metadata !"init-B")
; CHECK-NEXT: ret i1 %valid
define i1 @checkInitTypeB() {
entry:
  %valid = call i1 @llvm.type.test(i8* bitcast (void ()* @_CAOpropertyBiiHv to i8*), metadata !"init-B")
  ret i1 %valid
}

; CHECK-LABEL: define internal void @_CAOpropertyAiiHv_imp(i8 addrspace(1)** %slot) local_unnamed_addr
; CHECK-SAME: personality i8* bitcast (i32 (...)* @__gxx_personality_v0 to i8*)
; CHECK: alloca i8, align 1
; CHECK: call void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)* {{.*}}, i8 addrspace(1)** %slot)
; CHECK: ret void

; CHECK-LABEL: define internal void @_CAFprefixA_imp(i8 addrspace(1)** %slot0) local_unnamed_addr
; CHECK-SAME: personality i8* bitcast (i32 (...)* @__gxx_personality_v0 to i8*)
; CHECK: alloca i8, align 1
; CHECK: call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** %slot0)
; CHECK: ret void

; CHECK-DAG: ![[TYPE_FACTORY_A]] = !{i64 0, !"factory-A"}
; CHECK-DAG: ![[TYPE_FACTORY_B]] = !{i64 0, !"factory-B"}
; CHECK-DAG: ![[TYPE_INIT_A]] = !{i64 0, !"init-A"}
; CHECK-DAG: ![[TYPE_INIT_B]] = !{i64 0, !"init-B"}
!0 = !{i64 0, !"factory-A"}
!1 = !{i64 0, !"factory-B"}
!2 = !{i64 0, !"init-A"}
!3 = !{i64 0, !"init-B"}
