; RUN: split-file %s %t
; RUN: llc -mtriple=x86_64 -print-after=cj-barrier-lowering \
; RUN:   -o /dev/null < %t/cangjie.ll 2>&1 | FileCheck %s --check-prefix=LOWER
; RUN: llc -mtriple=x86_64 -filetype=obj -o %t/cangjie.o < %t/cangjie.ll
; RUN: llvm-readelf --symbols %t/cangjie.o \
; RUN:   | FileCheck %s --check-prefix=ELF
; RUN: llc -mtriple=x86_64 -print-after=cj-barrier-lowering \
; RUN:   -o /dev/null < %t/native.ll 2>&1 | FileCheck %s --check-prefix=NATIVE

; Cangjie barrier intrinsics must be lowered before instruction selection even
; when llc is invoked directly, without the wider --cangjie-pipeline.

; LOWER-LABEL: define void @gcread_generic_payload(
; LOWER-NOT: llvm.cj.gcread.generic.payload
; LOWER: call void @CJ_MCC_ReadGenericPayload(i8* %dst, i8 addrspace(1)* %obj, i32 %size)
;--- cangjie.ll
define void @gcread_generic_payload(i8* %dst, i8 addrspace(1)* %obj,
                                    i32 %size) #0 gc "cangjie" {
  call void @llvm.cj.gcread.generic.payload(i8* %dst,
                                             i8 addrspace(1)* %obj,
                                             i32 %size)
  ret void
}

; ELF: {{[0-9]+}}: {{[0-9a-f]+}} {{[0-9]+}} FUNC GLOBAL DEFAULT {{[0-9]+}} gcread_generic_payload
; ELF: {{[0-9]+}}: {{[0-9a-f]+}} {{[0-9]+}} NOTYPE GLOBAL DEFAULT UND CJ_MCC_ReadGenericPayload
; ELF-NOT: llvm.cj.gcread.generic.payload

declare void @llvm.cj.gcread.generic.payload(i8*, i8 addrspace(1)*, i32)

attributes #0 = { "leaf-function" }

; Scheduling the pass for every llc invocation must not add Cangjie runtime
; declarations to an ordinary module.
; NATIVE-NOT: GetGCPhase
; NATIVE-LABEL: define void @native(
; NATIVE-NOT: GetGCPhase
;--- native.ll
define void @native() {
  ret void
}
