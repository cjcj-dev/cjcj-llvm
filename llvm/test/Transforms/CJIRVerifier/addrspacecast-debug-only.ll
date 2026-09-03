; RUN: split-file %s %t
; RUN: opt -passes=cj-ir-verifier -disable-output < %t/allow-debug-slot.ll
; RUN: opt -passes=cj-ir-verifier -disable-output < %t/allow-dbg-value.ll
; RUN: not not opt -passes=cj-ir-verifier -disable-output < %t/reject-call.ll 2>&1 | FileCheck %s --check-prefix=CALL
; RUN: not not opt -passes=cj-ir-verifier -disable-output < %t/reject-slot-load.ll 2>&1 | FileCheck %s --check-prefix=SLOT
; RUN: not not opt -passes=cj-ir-verifier -disable-output < %t/reject-phi.ll 2>&1 | FileCheck %s --check-prefix=PHI
; RUN: opt '-passes=default<O0>' --cangjie-pipeline -disable-output < %t/allow-debug-slot.ll
; RUN: opt '-passes=default<O0>' --cangjie-pipeline -disable-output < %t/allow-dbg-value.ll
; RUN: not not opt '-passes=default<O0>' --cangjie-pipeline -disable-output < %t/reject-call.ll 2>&1 | FileCheck %s --check-prefix=CALL
; RUN: not not opt '-passes=default<O0>' --cangjie-pipeline -disable-output < %t/reject-slot-load.ll 2>&1 | FileCheck %s --check-prefix=SLOT
; RUN: not not opt '-passes=default<O0>' --cangjie-pipeline -disable-output < %t/reject-phi.ll 2>&1 | FileCheck %s --check-prefix=PHI

; CALL: AddrSpaceCast source must be addrspace(0)
; CALL: in function reject_call
; SLOT: in function reject_slot_load
; PHI: Addrspacecast result can only be used for store or call.
; PHI: in function reject_phi

;--- allow-debug-slot.ll
%Obj = type { i64 }

define void @allow_debug_slot(i8 addrspace(1)* %object) gc "cangjie" !dbg !5 {
entry:
  %obj.debug = alloca %Obj*, align 8
  %obj = bitcast i8 addrspace(1)* %object to %Obj addrspace(1)*
  %native = addrspacecast %Obj addrspace(1)* %obj to %Obj*
  store %Obj* %native, %Obj** %obj.debug, align 8
  call void @llvm.dbg.declare(metadata %Obj** %obj.debug, metadata !8, metadata !DIExpression()), !dbg !9
  ret void
}

declare void @llvm.dbg.declare(metadata, metadata, metadata)

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!3, !4}
!0 = distinct !DICompileUnit(language: DW_LANG_C_plus_plus, file: !1, producer: "cangjie", isOptimized: false, runtimeVersion: 0, emissionKind: FullDebug, enums: !2)
!1 = !DIFile(filename: "debug.cj", directory: ".")
!2 = !{}
!3 = !{i32 2, !"Dwarf Version", i32 4}
!4 = !{i32 2, !"Debug Info Version", i32 3}
!5 = distinct !DISubprogram(name: "allow_debug_slot", scope: !1, file: !1, line: 1, type: !6, scopeLine: 1, spFlags: DISPFlagDefinition, unit: !0, retainedNodes: !2)
!6 = !DISubroutineType(types: !7)
!7 = !{null}
!8 = !DILocalVariable(name: "obj", scope: !5, file: !1, line: 1, type: !10)
!9 = !DILocation(line: 1, column: 1, scope: !5)
!10 = !DIBasicType(name: "object", size: 64, encoding: DW_ATE_address)

;--- allow-dbg-value.ll
%Obj = type { i64 }

define void @allow_dbg_value(i8 addrspace(1)* %object) gc "cangjie" !dbg !5 {
entry:
  %obj = bitcast i8 addrspace(1)* %object to %Obj addrspace(1)*
  %native = addrspacecast %Obj addrspace(1)* %obj to %Obj*
  call void @llvm.dbg.value(metadata %Obj* %native, metadata !8, metadata !DIExpression()), !dbg !9
  ret void
}

declare void @llvm.dbg.value(metadata, metadata, metadata)

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!3, !4}
!0 = distinct !DICompileUnit(language: DW_LANG_C_plus_plus, file: !1, producer: "cangjie", isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug, enums: !2)
!1 = !DIFile(filename: "debug.cj", directory: ".")
!2 = !{}
!3 = !{i32 2, !"Dwarf Version", i32 4}
!4 = !{i32 2, !"Debug Info Version", i32 3}
!5 = distinct !DISubprogram(name: "allow_dbg_value", scope: !1, file: !1, line: 1, type: !6, scopeLine: 1, spFlags: DISPFlagDefinition, unit: !0, retainedNodes: !2)
!6 = !DISubroutineType(types: !7)
!7 = !{null}
!8 = !DILocalVariable(name: "obj", scope: !5, file: !1, line: 1, type: !10)
!9 = !DILocation(line: 1, column: 1, scope: !5)
!10 = !DIBasicType(name: "object", size: 64, encoding: DW_ATE_address)

;--- reject-call.ll
%Obj = type { i64 }

define void @reject_call(i8 addrspace(1)* %object) gc "cangjie" {
entry:
  %obj = bitcast i8 addrspace(1)* %object to %Obj addrspace(1)*
  %native = addrspacecast %Obj addrspace(1)* %obj to %Obj*
  call void @consume(%Obj* %native)
  ret void
}

declare void @consume(%Obj*)

;--- reject-slot-load.ll
%Obj = type { i64 }

define i64 @reject_slot_load(i8 addrspace(1)* %object) gc "cangjie" {
entry:
  %obj.debug = alloca %Obj*, align 8
  %obj = bitcast i8 addrspace(1)* %object to %Obj addrspace(1)*
  %native = addrspacecast %Obj addrspace(1)* %obj to %Obj*
  store %Obj* %native, %Obj** %obj.debug, align 8
  %reloaded = load %Obj*, %Obj** %obj.debug, align 8
  %field = getelementptr inbounds %Obj, %Obj* %reloaded, i32 0, i32 0
  %value = load i64, i64* %field, align 8
  ret i64 %value
}

;--- reject-phi.ll
%Obj = type { i64 }

@escaped = global %Obj* null

define void @reject_phi(i8 addrspace(1)* %object, i1 %condition) gc "cangjie" {
entry:
  %obj = bitcast i8 addrspace(1)* %object to %Obj addrspace(1)*
  %native = addrspacecast %Obj addrspace(1)* %obj to %Obj*
  br i1 %condition, label %left, label %right

left:
  br label %merge

right:
  br label %merge

merge:
  %selected = phi %Obj* [ %native, %left ], [ null, %right ]
  store %Obj* %selected, %Obj** @escaped, align 8
  ret void
}
