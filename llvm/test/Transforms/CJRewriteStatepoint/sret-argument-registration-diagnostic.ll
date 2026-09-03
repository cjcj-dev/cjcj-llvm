; RUN: opt -passes=cj-rewrite-statepoint -S < %s 2>&1 | FileCheck %s --check-prefix=DEFAULT
; RUN: not --crash opt -cj-spp-reject-unregistered-sret-arg -passes=cj-rewrite-statepoint -disable-output < %s 2>&1 | FileCheck %s --check-prefix=REJECT

target datalayout = "e-p:64:64-p1:64:64"

%S = type { i8 addrspace(1)*, i64 }

define void @fill(%S* noalias sret(%S) %result,
                  i8 addrspace(1)* %input) gc "cangjie" {
entry:
  %field = getelementptr inbounds %S, %S* %result, i32 0, i32 0
  store i8 addrspace(1)* %input, i8 addrspace(1)** %field
  ret void
}

define void @fill_pointer(i8 addrspace(1)** noalias sret(i8 addrspace(1)*) %result,
                          i8 addrspace(1)* %input) gc "cangjie" {
entry:
  store i8 addrspace(1)* %input, i8 addrspace(1)** %result
  ret void
}

; DEFAULT: sret-arg-unregistered caller_array fill
; DEFAULT-NOT: sret-arg-unregistered caller_registered
; DEFAULT-NOT: sret-arg-unregistered caller_abi_source
; DEFAULT-NOT: sret-arg-unregistered caller_sret_forward
; DEFAULT-NOT: sret-arg-unregistered caller_pointer_alloca
; DEFAULT-NOT: sret-arg-unregistered caller_pointer_abi_source
; DEFAULT-NOT: sret-arg-unregistered caller_pointer_sret_forward
; DEFAULT-LABEL: define i8 addrspace(1)* @caller_array
; DEFAULT: call token (...) @llvm.cj.gc.statepoint{{.*}}@fill
; DEFAULT-NOT: "struct-live"
; DEFAULT: ret i8 addrspace(1)*
;
; REJECT: sret-arg-unregistered caller_array fill
; REJECT: LLVM ERROR: Cangjie sret argument is not a registered root
define i8 addrspace(1)* @caller_array(i8 addrspace(1)* %input) gc "cangjie" {
entry:
  %slots = alloca [1 x %S], align 8
  %slot = getelementptr inbounds [1 x %S], [1 x %S]* %slots, i32 0, i32 0
  call void @fill(%S* sret(%S) %slot, i8 addrspace(1)* %input)
  %field = getelementptr inbounds %S, %S* %slot, i32 0, i32 0
  %value = load i8 addrspace(1)*, i8 addrspace(1)** %field
  ret i8 addrspace(1)* %value
}

; A whole entry-block struct alloca is registered by computeStructTypeLayouts.
; DEFAULT-LABEL: define i8 addrspace(1)* @caller_registered
; DEFAULT: call token (...) @llvm.cj.gc.statepoint{{.*}}@fill{{.*}}[ "struct-live"(%S* %slot) ]
define i8 addrspace(1)* @caller_registered(i8 addrspace(1)* %input) gc "cangjie" {
entry:
  %slot = alloca %S, align 8
  call void @fill(%S* sret(%S) %slot, i8 addrspace(1)* %input)
  %field = getelementptr inbounds %S, %S* %slot, i32 0, i32 0
  %value = load i8 addrspace(1)*, i8 addrspace(1)** %field
  ret i8 addrspace(1)* %value
}

; A noalias aggregate ABI source remains owned by its originating caller.
define void @caller_abi_source(%S* noalias %slot,
                               i8 addrspace(1)* %input) gc "cangjie" {
entry:
  call void @fill(%S* sret(%S) %slot, i8 addrspace(1)* %input)
  ret void
}

; An sret Argument can forward the caller-owned result slot.
define void @caller_sret_forward(%S* noalias sret(%S) %slot,
                                 i8 addrspace(1)* %input) gc "cangjie" {
entry:
  call void @fill(%S* sret(%S) %slot, i8 addrspace(1)* %input)
  ret void
}

; A whole entry-block slot for a GC pointer participates in pointer liveness.
define i8 addrspace(1)* @caller_pointer_alloca(
    i8 addrspace(1)* %input) gc "cangjie" {
entry:
  %slot = alloca i8 addrspace(1)*, align 8
  call void @fill_pointer(i8 addrspace(1)** sret(i8 addrspace(1)*) %slot,
                          i8 addrspace(1)* %input)
  %value = load i8 addrspace(1)*, i8 addrspace(1)** %slot
  ret i8 addrspace(1)* %value
}

; A noalias ABI source can own a GC-pointer result slot.
define void @caller_pointer_abi_source(i8 addrspace(1)** noalias %slot,
                                       i8 addrspace(1)* %input) gc "cangjie" {
entry:
  call void @fill_pointer(i8 addrspace(1)** sret(i8 addrspace(1)*) %slot,
                          i8 addrspace(1)* %input)
  ret void
}

; A pointer-valued sret Argument can forward its caller-owned result slot.
define void @caller_pointer_sret_forward(
    i8 addrspace(1)** noalias sret(i8 addrspace(1)*) %slot,
    i8 addrspace(1)* %input) gc "cangjie" {
entry:
  call void @fill_pointer(i8 addrspace(1)** sret(i8 addrspace(1)*) %slot,
                          i8 addrspace(1)* %input)
  ret void
}
