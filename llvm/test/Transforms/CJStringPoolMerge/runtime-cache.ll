; RUN: opt -passes=cj-string-pool-merge -S %s | FileCheck %s --check-prefix=INITIALIZED
; RUN: opt -passes=cj-string-pool-merge -cj-string-pool-merge=false -S %s | FileCheck %s --check-prefix=INITIALIZED
; RUN: opt -passes=cj-string-pool-merge -S %s | FileCheck %s
; RUN: opt -passes=cj-string-pool-merge -cj-string-pool-merge=false -S %s | FileCheck %s
; RUN: opt -passes=cj-string-pool-merge %s -o %t.on.bc
; RUN: llc --cangjie-pipeline -print-after=cj-barrier-lowering -o /dev/null %t.on.bc 2>&1 | FileCheck %s --check-prefix=BARRIER
; RUN: opt -passes=cj-string-pool-merge -cj-string-pool-merge=false %s -o %t.off.bc
; RUN: llc --cangjie-pipeline -print-after=cj-barrier-lowering -o /dev/null %t.off.bc 2>&1 | FileCheck %s --check-prefix=BARRIER
;
; The Cangjie runtime materializes and later heals registered String caches.
; CJGlobalValue distinguishes these writable roots from deferred constants.
; ZGC: zBarrierSet.inline.hpp:258-265 stores colored references to native roots.
target triple = "x86_64-unknown-linux-gnu"
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
; CHECK: @cache = global %"record.std.core:String" zeroinitializer
@cache = global %"record.std.core:String" zeroinitializer #0
; A root may already have a static initializer and still require healing.
; INITIALIZED: @initialized_cache = global %"record.std.core:String"
; CHECK: @initialized_cache = global %"record.std.core:String"
@initialized_cache = global %"record.std.core:String" { i8 addrspace(1)* null, i32 0, i32 1 } #0
; The official deferred literal remains eligible for constness restoration.
; CHECK: @literal = constant %"record.std.core:String" zeroinitializer
@literal = global %"record.std.core:String" zeroinitializer #1

define void @materialize(i8 addrspace(1)* %value) {
  %slot = getelementptr %"record.std.core:String", %"record.std.core:String"* @cache, i32 0, i32 0
  call void @CJ_MCC_WriteStaticRef(i8 addrspace(1)** %slot, i8 addrspace(1)* %value)
  ret void
}
declare void @CJ_MCC_WriteStaticRef(i8 addrspace(1)**, i8 addrspace(1)*)

; Observe the real static-root barrier lowering after either pool setting.
; BARRIER-LABEL: define void @write_initialized_cache(
; BARRIER: call void @CJ_MCC_WriteStaticRef
; BARRIER-LABEL: define i8 addrspace(1)* @read_initialized_cache(
; BARRIER: call i8 addrspace(1)* @CJ_MCC_ReadStaticRef
define void @write_initialized_cache(i8 addrspace(1)* %value) gc "cangjie" {
  %slot = getelementptr %"record.std.core:String", %"record.std.core:String"* @initialized_cache, i32 0, i32 0
  call void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)* %value, i8 addrspace(1)** %slot)
  ret void
}
define i8 addrspace(1)* @read_initialized_cache() gc "cangjie" {
  %slot = getelementptr %"record.std.core:String", %"record.std.core:String"* @initialized_cache, i32 0, i32 0
  %value = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** %slot)
  ret i8 addrspace(1)* %value
}
declare void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)*, i8 addrspace(1)**)
declare i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)**)
attributes #0 = { "cjstring_literal" "CJGlobalValue" }
attributes #1 = { "cjstring_literal" }
