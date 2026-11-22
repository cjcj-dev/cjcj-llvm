; REQUIRES: webassembly-registered-target
; RUN: split-file %s %t
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -print-after=cj-barrier-lowering \
; RUN:   -o /dev/null < %t/main.ll 2>&1 \
; RUN:   | FileCheck %t/main.ll --check-prefixes=CHECK,X86
; RUN: llc --cangjie-pipeline -mtriple=wasm32-unknown-wasi \
; RUN:   -print-after=cj-barrier-lowering -o /dev/null < %t/main.ll 2>&1 \
; RUN:   | FileCheck %t/main.ll --check-prefixes=CHECK,WASM
; RUN: not llc --cangjie-pipeline -mtriple=x86_64 -o /dev/null \
; RUN:   %t/unproven-arg.ll 2>&1 | FileCheck %s --check-prefix=UNPROVEN
; RUN: not llc --cangjie-pipeline -mtriple=wasm32-unknown-wasi -o /dev/null \
; RUN:   %t/unproven-size.ll 2>&1 | FileCheck %s --check-prefix=UNPROVEN

; The frontend names an AggType by its own LLVM struct type. A named struct
; that no value references is dropped when the module is written as bitcode,
; so the llc of a separate opt/llc pipeline cannot resolve the name (std.convert
; writes Array<Tuple<UInt64,UInt64,UInt64>> elements this way). The GC bitmap
; must come from the exact struct allocated by the stack side of the copy: the
; same one a resolvable AggType of that struct produces.

;--- main.ll
%rec = type { i8 addrspace(1)*, i64, i64 }

; CHECK-LABEL: define void @write_named_aggtype(
; The reference word at offset 0 is the only bitmap bit (bit 63 tags inline).
; X86: call void @CJ_MCC_WriteStructField({{.*}}, i64 24, i8* [[TIB:inttoptr \(i64 -9223372036854775807 to i8\*\)]])
; WASM: call void @CJ_MCC_WriteStructField({{.*}}, i32 24, i8* [[TIB:bitcast \(%BitMapInstance\* @rec.bitmap to i8\*\)]])
; CHECK: ret void
define void @write_named_aggtype(i8 addrspace(1)* %base,
                                 i8 addrspace(1)* %dst) gc "cangjie" {
entry:
  %slot = alloca %rec, align 8
  %src = bitcast %rec* %slot to i8*
  call void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)* %base,
                                         i8 addrspace(1)* %dst,
                                         i8* %src, i64 24), !AggType !0
  ret void
}

; CHECK-LABEL: define void @write_unserialized_aggtype(
; CHECK: call void @CJ_MCC_WriteStructField({{.*}}, i{{32|64}} 24, i8* [[TIB]])
; CHECK: ret void
define void @write_unserialized_aggtype(i8 addrspace(1)* %base,
                                        i8 addrspace(1)* %dst) gc "cangjie" {
entry:
  %slot = alloca %rec, align 8
  %src = bitcast %rec* %slot to i8*
  call void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)* %base,
                                         i8 addrspace(1)* %dst,
                                         i8* %src, i64 24), !AggType !1
  ret void
}

declare void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)*,
                                          i8 addrspace(1)*, i8*, i64)

!0 = !{!"rec"}
!1 = !{!"Struct-_CNat5ArrayIG_E<Tuple(UInt64,UInt64,UInt64)>"}

; UNPROVEN: CJBarrierLowering: AggType 'Struct-missing' of 'llvm.cj.gcwrite.struct.{{[^']*}}' in 'write' names no struct type in this module

;--- unproven-arg.ll
; An unknown source proves no layout: fail closed instead of guessing.
define void @write(i8 addrspace(1)* %base, i8 addrspace(1)* %dst,
                   i8* %src) gc "cangjie" {
entry:
  call void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)* %base,
                                         i8 addrspace(1)* %dst,
                                         i8* %src, i64 24), !AggType !0
  ret void
}
declare void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)*,
                                          i8 addrspace(1)*, i8*, i64)
!0 = !{!"Struct-missing"}

;--- unproven-size.ll
; A stack struct whose size differs from the copy is not its layout.
%small = type { i8 addrspace(1)*, i64 }
define void @write(i8 addrspace(1)* %base, i8 addrspace(1)* %dst) gc "cangjie" {
entry:
  %slot = alloca %small, align 8
  %src = bitcast %small* %slot to i8*
  call void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)* %base,
                                         i8 addrspace(1)* %dst,
                                         i8* %src, i64 24), !AggType !0
  ret void
}
declare void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)*,
                                          i8 addrspace(1)*, i8*, i64)
!0 = !{!"Struct-missing"}
