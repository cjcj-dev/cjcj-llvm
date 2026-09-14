; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O0 -print-after=cj-barrier-lowering -o %t.O0.s < %s 2>&1 | FileCheck %s --check-prefix=IR --implicit-check-not='call cangjiegc i64 @GetGCPhase' --implicit-check-not=gcNoRunning
; RUN: FileCheck %s --check-prefix=ASM --implicit-check-not=GetGCPhase < %t.O0.s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 -print-after=cj-barrier-lowering -o %t.O2.s < %s 2>&1 | FileCheck %s --check-prefix=IR --implicit-check-not='call cangjiegc i64 @GetGCPhase' --implicit-check-not=gcNoRunning
; RUN: FileCheck %s --check-prefix=ASM --implicit-check-not=GetGCPhase < %t.O2.s
;
; ZGC zBarrierSet.inline.hpp:265 stores store_good(value) into native roots.
; Initialization and subsequent reference/aggregate writes must reach the
; runtime colour producer regardless of GC phase. A raw store or memcpy is
; not a valid alternative merely because the collector is idle.

%payload = type { i64, i8 addrspace(1)* }
@root = global i8 addrspace(1)* null
@aggregate = global %payload zeroinitializer

; IR-LABEL: define void @initialize_root(
; IR-NOT: store i8 addrspace(1)*
; IR: call void @CJ_MCC_WriteStaticRef(i8 addrspace(1)* %value, i8 addrspace(1)** @root)
; IR-NOT: store i8 addrspace(1)*
; IR: ret void
; ASM-LABEL: initialize_root:
; ASM: {{callq|jmp}} CJ_MCC_WriteStaticRef
; ASM: .Lfunc_end
define void @initialize_root(i8 addrspace(1)* %value) gc "cangjie" {
  call void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)* %value, i8 addrspace(1)** @root)
  ret void
}

; IR-LABEL: define void @replace_root(
; IR-NOT: store i8 addrspace(1)*
; IR: call void @CJ_MCC_WriteStaticRef(i8 addrspace(1)* %value, i8 addrspace(1)** %slot)
; IR-NOT: store i8 addrspace(1)*
; IR: ret void
; ASM-LABEL: replace_root:
; ASM: {{callq|jmp}} CJ_MCC_WriteStaticRef
; ASM: .Lfunc_end
define void @replace_root(i8 addrspace(1)* %value, i8 addrspace(1)** %slot) gc "cangjie" {
  call void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)* %value, i8 addrspace(1)** %slot)
  ret void
}

; IR-LABEL: define void @write_static_struct(
; IR-NOT: llvm.memcpy
; IR: call void @CJ_MCC_WriteStaticStruct(i8* bitcast (%payload* @aggregate to i8*), i64 16, i8* %src, i64 16, i8* {{.*}})
; IR-NOT: llvm.memcpy
; IR: ret void
; ASM-LABEL: write_static_struct:
; ASM: {{callq|jmp}} CJ_MCC_WriteStaticStruct
; ASM: .Lfunc_end
define void @write_static_struct(i8* %src) gc "cangjie" {
  call void @llvm.cj.gcwrite.static.struct.i64(i8* bitcast (%payload* @aggregate to i8*), i8* %src, i64 16), !AggType !0
  ret void
}

declare void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)*, i8 addrspace(1)**)
declare void @llvm.cj.gcwrite.static.struct.i64(i8*, i8*, i64)
!0 = !{!"payload"}
