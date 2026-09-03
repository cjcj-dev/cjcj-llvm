; RUN: opt -passes=cj-rewrite-statepoint -S < %s 2>&1 | FileCheck %s --check-prefix=DEFAULT
; RUN: not --crash opt -cj-spp-reject-unregistered-sret-arg -passes=cj-rewrite-statepoint -disable-output < %s 2>&1 | FileCheck %s --check-prefix=REJECT

target datalayout = "e-p:64:64-p1:64:64"

%S = type { i8 addrspace(1)*, i64 }

declare i32 @personality_function()
declare void @fill(%S* noalias sret(%S), i8 addrspace(1)*)

; DEFAULT: sret-arg-unregistered invoke_array fill
; DEFAULT-LABEL: define i8 addrspace(1)* @invoke_array
; DEFAULT: invoke token {{.*}}@llvm.cj.gc.statepoint{{.*}}@fill
;
; REJECT: sret-arg-unregistered invoke_array fill
; REJECT: LLVM ERROR: Cangjie sret argument is not a registered root
define i8 addrspace(1)* @invoke_array(i8 addrspace(1)* %input)
    gc "cangjie" personality i32 ()* @personality_function {
entry:
  %slots = alloca [1 x %S], align 8
  %slot = getelementptr inbounds [1 x %S], [1 x %S]* %slots, i32 0, i32 0
  invoke void @fill(%S* sret(%S) %slot, i8 addrspace(1)* %input)
      to label %normal unwind label %exceptional

normal:
  %field = getelementptr inbounds %S, %S* %slot, i32 0, i32 0
  %value = load i8 addrspace(1)*, i8 addrspace(1)** %field
  ret i8 addrspace(1)* %value

exceptional:
  %landingpad = landingpad token
      cleanup
  ret i8 addrspace(1)* null
}
