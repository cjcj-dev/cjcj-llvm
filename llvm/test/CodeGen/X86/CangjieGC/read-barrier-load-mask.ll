; ZGC x86:457-469: mask loads remain unconditional with fixed field offsets.
; RUN: llc --cangjie-pipeline -mtriple=x86_64 \
; RUN:   -print-module-scope -print-after=cj-barrier-lowering \
; RUN:   -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 \
; RUN:   -filetype=obj -o - < %s | llvm-readelf --symbols - \
; RUN:   | FileCheck %s --check-prefix=ELF

; CHECK-LABEL: define i8 addrspace(1)* @read_ref(
; CHECK: getelementptr i8, i8* %cj.gcdata{{[0-9]*}}, i64 8
; CHECK: [[MASK:%.*]] = load i64, i64* {{%.*}}
; CHECK-NOT: cj.loadbadmask.ispresent
; CHECK: [[BAD:%.*]] = and i64 {{%.*}}, [[MASK]]

; The store side is colour-tested and painted unconditionally too.
; CHECK-LABEL: define void @write_ref(
; CHECK: getelementptr i8, i8* %cj.gcdata{{[0-9]*}}, i64 32
; CHECK: getelementptr i8, i8* %cj.gcdata{{[0-9]*}}, i64 24

; ELF: Symbol table
; ELF-NOT: g_cjLoadBadMaskOffset
; ELF: CJ_MCC_ReadRefField
; ELF-NOT: g_cjLoadBadMaskOffset

define i8 addrspace(1)* @read_ref(i8 addrspace(1)* %obj,
                                  i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
entry:
  %ref = call i8 addrspace(1)* @llvm.cj.gcread.ref(
      i8 addrspace(1)* %obj, i8 addrspace(1)* addrspace(1)* %field)
  ret i8 addrspace(1)* %ref
}

define void @write_ref(i8 addrspace(1)* %value, i8 addrspace(1)* %obj,
                       i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
entry:
  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value,
      i8 addrspace(1)* %obj, i8 addrspace(1)* addrspace(1)* %field, i32 1)
  ret void
}

declare i8 addrspace(1)* @llvm.cj.gcread.ref(
    i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)
