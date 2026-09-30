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

%record = type { i8 addrspace(1)* }
define void @ordinary_struct(i8 addrspace(1)* %root, i8 addrspace(1)** %out) #0 gc "cangjie" {
  %slot = alloca %record, align 8
  %field = getelementptr %record, %record* %slot, i32 0, i32 0
  store i8 addrspace(1)* %root, i8 addrspace(1)** %field
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, void ()* @checkpoint, i32 0, i32 0) [ "struct-live"(%record* %slot) ]
  %value = load i8 addrspace(1)*, i8 addrspace(1)** %field
  store i8 addrspace(1)* %value, i8 addrspace(1)** %out
  ret void
}

define void @ordinary_line() #0 gc "cangjie" !dbg !4 {
  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, void ()* @checkpoint, i32 0, i32 0), !dbg !7
  ret void, !dbg !7
}
!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!2, !3}
!0 = distinct !DICompileUnit(language: DW_LANG_C_plus_plus, file: !1, producer: "test", isOptimized: false, runtimeVersion: 0, emissionKind: FullDebug)
!1 = !DIFile(filename: "empty-callsite-domain.cj", directory: "/")
!2 = !{i32 2, !"Dwarf Version", i32 4}
!3 = !{i32 2, !"Debug Info Version", i32 3}
!4 = distinct !DISubprogram(name: "ordinary_line", scope: !1, file: !1, line: 1, type: !5, scopeLine: 1, spFlags: DISPFlagDefinition, unit: !0)
!5 = !DISubroutineType(types: !6)
!6 = !{null}
!7 = !DILocation(line: 7, column: 1, scope: !4)
