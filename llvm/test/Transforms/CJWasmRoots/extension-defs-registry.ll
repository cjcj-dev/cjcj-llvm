; RUN: opt -passes=cj-wasm-roots,verify -S %s | FileCheck %s
; RUN: opt -passes=cj-wasm-roots,cj-wasm-roots,verify -S %s | FileCheck %s --check-prefix=ONCE
; RUN: sed -e 's/wasm32-unknown-wasi/x86_64-unknown-linux-gnu/' %s > %t.x86.ll
; RUN: opt -passes=cj-wasm-roots -S %t.x86.ll | FileCheck %s --check-prefix=NATIVE
target datalayout = "e-m:e-p:32:32-p1:32:32-i64:64-n32:64-S128-ni:1"
target triple = "wasm32-unknown-wasi"

; Every package's "InnerTypeExtensions" arrays must reach the wasm32 runtime
; registry: nothing else references them, so without the constructor wasm-ld
; drops them and CJ_MCC_GetMTable cannot see a cross-package `extend`. Empty
; arrays are skipped and the constructor is emitted once per module. Outer
; arrays (extends of types defined in another package, e.g. Int64) count too.

%ExtensionDef = type { i32, i8, i8, i16, i8*, i8*, i8*, i8* }

@ed.a = internal global %ExtensionDef zeroinitializer
@ed.b = internal global %ExtensionDef zeroinitializer
@ExternalExtensionDefs = private global [2 x %ExtensionDef*] [%ExtensionDef* @ed.a, %ExtensionDef* @ed.b] #0
@NonExternalExtensionDefs = private global [1 x %ExtensionDef*] [%ExtensionDef* @ed.b] #0
@EmptyDefs = private global [0 x %ExtensionDef*] zeroinitializer #0
@ed.int64 = internal global %ExtensionDef zeroinitializer
@OuterTypeExtensions = private global [1 x %ExtensionDef*] [%ExtensionDef* @ed.int64] #1
@Unrelated = private global [1 x %ExtensionDef*] [%ExtensionDef* @ed.a]

attributes #0 = { "InnerTypeExtensions" }
attributes #1 = { "OuterTypeExtensions" }

; CHECK: @llvm.global_ctors = appending global {{.*}} @cj.wasm.register_extension_defs
; CHECK-LABEL: define internal void @cj.wasm.register_extension_defs()
; CHECK-NEXT: entry:
; CHECK-NEXT: call void @CJ_MCC_WasmRegisterExtensionDefs({{.*}}@ExternalExtensionDefs{{.*}}, i32 2)
; CHECK-NEXT: call void @CJ_MCC_WasmRegisterExtensionDefs({{.*}}@NonExternalExtensionDefs{{.*}}, i32 1)
; CHECK-NEXT: call void @CJ_MCC_WasmRegisterExtensionDefs({{.*}}@OuterTypeExtensions{{.*}}, i32 1)
; CHECK-NEXT: ret void
; CHECK-NOT: @Unrelated

; ONCE-COUNT-1: define internal void @cj.wasm.register_extension_defs()
; ONCE-NOT: define internal void @cj.wasm.register_extension_defs

; NATIVE-NOT: register_extension_defs
