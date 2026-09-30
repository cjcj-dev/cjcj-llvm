; RUN: llc --cangjie-pipeline -mtriple=x86_64-unknown-linux-gnu -filetype=obj %s -o %t.o
; RUN: %python %S/Inputs/check-empty-callsite-domain.py %t.o
; RUN: llc --cangjie-pipeline -mtriple=aarch64-unknown-linux-gnu -filetype=obj %s -o %t.a64.o
; RUN: %python %S/Inputs/check-empty-callsite-domain.py %t.a64.o
;
; Ordinary records follow upstream StackMaps.cpp:774-778 (5d095aed).
; Return polls own their PC, including empty maps, as OopMapSet::add_gc_map
; (compiler/oopMap.cpp:367-386). Decode the emitted object, not a model.

define void @ordinary_empty() #0 gc "cangjie" {
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, void ()* @checkpoint, i32 0, i32 0)
  ret void
}

define void @ordinary_root(i8 addrspace(1)* %root, i8 addrspace(1)** %out) #0 gc "cangjie" {
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, void ()* @checkpoint, i32 0, i32 0) [ "gc-live"(i8 addrspace(1)* %root) ]
  %relocated = call i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token %token, i32 0, i32 0)
  store i8 addrspace(1)* %relocated, i8 addrspace(1)** %out
  ret void
}

define void @return_empty() gc "cangjie" {
  ret void
}

define i8 addrspace(1)* @return_root(i8 addrspace(1)* %root) gc "cangjie" {
  ret i8 addrspace(1)* %root
}

declare token @llvm.cj.gc.statepoint(...)
declare i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token, i32, i32)
declare void @checkpoint()
attributes #0 = { "gc-leaf-function" }
