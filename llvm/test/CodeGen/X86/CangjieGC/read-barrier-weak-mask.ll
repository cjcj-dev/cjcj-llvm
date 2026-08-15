; RUN: llc --cangjie-pipeline -mtriple=x86_64 \
; RUN:   -print-module-scope -print-after=cj-barrier-lowering \
; RUN:   -o /dev/null < %s 2>&1 \
; RUN:   | FileCheck %s --check-prefix=DEFAULT
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -cj-weak-load-bad-mask \
; RUN:   -cj-generational-post-barrier -print-module-scope \
; RUN:   -print-after=cj-barrier-lowering \
; RUN:   -o /dev/null < %s 2>&1 | FileCheck %s --check-prefix=WEAK
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -cj-weak-load-bad-mask \
; RUN:   -filetype=obj -o - < %s | llvm-readelf --symbols - \
; RUN:   | FileCheck %s --check-prefix=ELF

; DEFAULT: @g_cjLoadBadMask = external global i64
; DEFAULT-LABEL: define i8 addrspace(1)* @read_ref(
; DEFAULT: [[DEFAULT_MASK:%.*]] = load i64, i64* @g_cjLoadBadMask
; DEFAULT-NOT: cj.loadbadmask.ispresent
; DEFAULT: [[DEFAULT_BAD:%.*]] = and i64 {{%.*}}, [[DEFAULT_MASK]]

; WEAK: @g_cjLoadBadMask = extern_weak global i64
; WEAK-LABEL: define i8 addrspace(1)* @read_ref(
; WEAK: [[PRESENT:%.*]] = icmp ne i64* @g_cjLoadBadMask, null
; WEAK-NEXT: br i1 [[PRESENT]], label %cj.loadbadmask.present, label %cj.loadbadmask.merge
; WEAK: cj.loadbadmask.present:
; WEAK-NEXT: [[RUNTIME_MASK:%.*]] = load i64, i64* @g_cjLoadBadMask
; WEAK-NEXT: br label %cj.loadbadmask.merge
; WEAK: cj.loadbadmask.merge:
; WEAK-NEXT: [[MASK:%.*]] = phi i64 [ [[RUNTIME_MASK]], %cj.loadbadmask.present ], [ -281474976710656, %entry ]
; WEAK-NEXT: [[BAD:%.*]] = and i64 {{%.*}}, [[MASK]]
; WEAK: call void @CJ_MCC_WriteRefField

; ELF: NOTYPE WEAK DEFAULT UND g_cjLoadBadMask

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
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value,
      i8 addrspace(1)* %obj, i8 addrspace(1)* addrspace(1)* %field)
  ret void
}

declare i8 addrspace(1)* @llvm.cj.gcread.ref(
    i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
declare void @llvm.cj.gcwrite.ref(
    i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
