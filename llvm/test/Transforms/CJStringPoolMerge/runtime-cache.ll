; RUN: opt -passes=cj-string-pool-merge -S %s | FileCheck %s
; RUN: opt -passes=cj-string-pool-merge -cj-string-pool-merge=false -S %s | FileCheck %s
;
; The Cangjie runtime materializes and later heals registered String caches.
; CJGlobalValue distinguishes these writable roots from deferred constants.
; ZGC: zBarrierSet.inline.hpp:258-265 stores colored references to native roots.
target triple = "x86_64-unknown-linux-gnu"
%"record.std.core:String" = type { i8 addrspace(1)*, i32, i32 }
; CHECK: @cache = global %"record.std.core:String" zeroinitializer
@cache = global %"record.std.core:String" zeroinitializer #0
; A root may already have a static initializer and still require healing.
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
attributes #0 = { "cjstring_literal" "CJGlobalValue" }
attributes #1 = { "cjstring_literal" }
