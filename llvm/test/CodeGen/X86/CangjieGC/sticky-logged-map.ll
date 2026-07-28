; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 \
; RUN:   -cjcj-sticky-logged-map=false -print-after=cj-barrier-lowering \
; RUN:   -o /dev/null < %s 2>&1 \
; RUN:   | FileCheck %s --check-prefix=OFF
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 \
; RUN:   -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 \
; RUN:   | FileCheck %s --check-prefix=ON
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 \
; RUN:   -cjcj-sticky-logged-map -print-after=cj-barrier-lowering \
; RUN:   -o /dev/null < %s 2>&1 | FileCheck %s --check-prefix=ON
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O0 \
; RUN:   -cjcj-sticky-logged-map -print-after=cj-barrier-lowering \
; RUN:   -o /dev/null < %s 2>&1 | FileCheck %s --check-prefix=ON

; OFF-NOT: stickySourceCheck
; OFF-NOT: __cj_sticky_logged_base
; OFF-NOT: __cj_sticky_heap_base
; OFF-NOT: __cj_sticky_heap_size

; ON-LABEL: define void @sticky_gcwrite_ref
; ON: call cangjiegccc i32 @GetGCPhase()
; ON: icmp sle i32 {{.*}}, 8
; ON: br i1 {{.*}}, label %stickySourceCheck, label %gcRunning
; ON: gcRunning:
; ON: call void @CJ_MCC_WriteRefField
; ON: stickySourceCheck:
; ON: icmp eq i8 addrspace(1)* %obj, null
; ON: br i1 {{.*}}, label %gcNoRunning, label %stickyMapReadyCheck
; ON: stickyMapReadyCheck:
; ON: load i8*, i8** @__cj_sticky_logged_base
; ON: icmp eq i8* {{.*}}, null
; ON: br i1 {{.*}}, label %gcNoRunning, label %stickyRangeCheck
; ON: stickyRangeCheck:
; ON: ptrtoint i8 addrspace(1)* %obj to i64
; ON: load i64, i64* @__cj_sticky_heap_base
; ON: sub i64
; ON: load i64, i64* @__cj_sticky_heap_size
; ON: icmp ult i64
; ON: br i1 {{.*}}, label %stickyMapCheck, label %gcNoRunning
; ON: stickyMapCheck:
; ON: lshr i64 {{.*}}, 8
; ON: getelementptr inbounds i8, i8* {{.*}}, i64
; ON: load volatile i8, i8* {{.*}}, align 1
; ON: icmp ne i8 {{.*}}, 0
; ON: br i1 {{.*}}, label %gcNoRunning, label %gcRunning
; ON: gcNoRunning:
; ON: store i8 addrspace(1)* %value

define void @sticky_gcwrite_ref(i8 addrspace(1)* %obj,
                                i8 addrspace(1)* %value,
                                i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
entry:
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value,
                                  i8 addrspace(1)* %obj,
                                  i8 addrspace(1)* addrspace(1)* %field)
  ret void
}

; ON-LABEL: define void @sticky_gcwrite_struct
; ON: br i1 {{.*}}, label %stickySourceCheck, label %gcRunning
; ON: stickyMapCheck:
; ON: lshr i64 {{.*}}, 8
; ON: load volatile i8
; ON: br i1 {{.*}}, label %gcNoRunning, label %gcRunning
; ON: gcNoRunning:
; ON: call void @llvm.memcpy

define void @sticky_gcwrite_struct(i8 addrspace(1)* %obj,
                                   i8 addrspace(1)* %dst,
                                   i8* %src) gc "cangjie" {
entry:
  call void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)* %obj,
                                         i8 addrspace(1)* %dst, i8* %src,
                                         i64 8), !AggType !0
  ret void
}

; ON-LABEL: define void @sticky_array_copy_ref
; ON: br i1 {{.*}}, label %stickySourceCheck, label %gcRunning
; ON: stickySourceCheck:
; ON: icmp eq i8 addrspace(1)* %dst.obj, null
; ON: stickyMapCheck:
; ON: lshr i64 {{.*}}, 8
; ON: load volatile i8
; ON: br i1 {{.*}}, label %gcNoRunning, label %gcRunning
; ON: gcNoRunning:
; ON: call void @llvm.memmove

define void @sticky_array_copy_ref(i8 addrspace(1)* %dst.obj,
                                   i8 addrspace(1)* %dst,
                                   i8 addrspace(1)* %src.obj,
                                   i8 addrspace(1)* %src) gc "cangjie" {
entry:
  call void @llvm.cj.array.copy.ref.i64(i8 addrspace(1)* %dst.obj,
                                        i8 addrspace(1)* %dst,
                                        i8 addrspace(1)* %src.obj,
                                        i8 addrspace(1)* %src, i64 8)
  ret void
}

; ON-LABEL: define void @sticky_array_copy_struct
; ON: br i1 {{.*}}, label %stickySourceCheck, label %gcRunning
; ON: stickyMapCheck:
; ON: load volatile i8
; ON: br i1 {{.*}}, label %gcNoRunning, label %gcRunning
; ON: gcNoRunning:
; ON: call void @llvm.memmove

define void @sticky_array_copy_struct(i8 addrspace(1)* %dst.obj,
                                      i8 addrspace(1)* %dst,
                                      i8 addrspace(1)* %src.obj,
                                      i8 addrspace(1)* %src) gc "cangjie" {
entry:
  call void @llvm.cj.array.copy.struct.i64(i8 addrspace(1)* %dst.obj,
                                           i8 addrspace(1)* %dst,
                                           i8 addrspace(1)* %src.obj,
                                           i8 addrspace(1)* %src, i64 8)
  ret void
}

; ON-LABEL: define void @sticky_atomic_store
; ON: br i1 {{.*}}, label %stickySourceCheck, label %gcRunning
; ON: gcRunning:
; ON: call void @CJ_MCC_AtomicWriteReference{{.*}}i32 5
; ON: stickyMapCheck:
; ON: load volatile i8
; ON: br i1 {{.*}}, label %gcNoRunning, label %gcRunning
; ON: gcNoRunning:
; ON: store atomic i8 addrspace(1)* %value{{.*}}seq_cst

define void @sticky_atomic_store(i8 addrspace(1)* %obj,
                                 i8 addrspace(1)* %value,
                                 i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
entry:
  call void @llvm.cj.atomic.store(i8 addrspace(1)* %value,
                                   i8 addrspace(1)* %obj,
                                   i8 addrspace(1)* addrspace(1)* %field,
                                   i32 5)
  ret void
}

; Static writes have no heap owner and must not enter the logged-map path.
; ON-LABEL: define void @sticky_static_ref
; ON-NOT: stickySourceCheck
; ON: store i8 addrspace(1)* %value
; ON-NOT: stickySourceCheck
; ON: ret void

define void @sticky_static_ref(i8 addrspace(1)* %value,
                               i8 addrspace(1)** %field) gc "cangjie" {
entry:
  call void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)* %value,
                                         i8 addrspace(1)** %field)
  ret void
}

; A compile-time null owner keeps the existing direct-store fast path.
; ON-LABEL: define void @sticky_null_owner
; ON-NOT: stickySourceCheck
; ON: store i8 addrspace(1)* %value
; ON-NOT: stickySourceCheck
; ON: ret void

define void @sticky_null_owner(i8 addrspace(1)* %value,
                               i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
entry:
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value,
                                  i8 addrspace(1)* null,
                                  i8 addrspace(1)* addrspace(1)* %field)
  ret void
}

%StickyAgg = type { i8 addrspace(1)* }
@sticky.type.anchor = external global %StickyAgg

declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*,
                                  i8 addrspace(1)* addrspace(1)*)
declare void @llvm.cj.gcwrite.static.ref(i8 addrspace(1)*,
                                         i8 addrspace(1)**)
declare void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)*,
                                         i8 addrspace(1)*, i8*, i64)
declare void @llvm.cj.array.copy.ref.i64(i8 addrspace(1)*,
                                        i8 addrspace(1)*,
                                        i8 addrspace(1)*,
                                        i8 addrspace(1)*, i64)
declare void @llvm.cj.array.copy.struct.i64(i8 addrspace(1)*,
                                           i8 addrspace(1)*,
                                           i8 addrspace(1)*,
                                           i8 addrspace(1)*, i64)
declare void @llvm.cj.atomic.store(i8 addrspace(1)*, i8 addrspace(1)*,
                                   i8 addrspace(1)* addrspace(1)*, i32)

!0 = !{!"StickyAgg"}
