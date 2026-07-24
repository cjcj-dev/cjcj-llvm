; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 \
; RUN:   -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 \
; RUN:   | FileCheck %s --check-prefix=OFF
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 \
; RUN:   -cjcj-sticky-log-barrier -print-after=cj-barrier-lowering \
; RUN:   -o /dev/null < %s 2>&1 | FileCheck %s --check-prefix=ON

; OFF-NOT: stickySourceCheck
; OFF-LABEL: define void @sticky_gcwrite_ref_1
; OFF-NOT: stickySourceCheck

; ON-LABEL: define void @sticky_gcwrite_ref_1
; ON: call cangjiegccc i32 @GetGCPhase()
; ON: icmp sle i32 {{.*}}, 8
; ON: br i1 {{.*}}, label %stickySourceCheck, label %gcRunning
; ON: gcRunning:
; ON: call void @CJ_MCC_WriteRefField
; ON: stickySourceCheck:
; ON: icmp eq i8 addrspace(1)* %obj, null
; ON: br i1 {{.*}}, label %gcNoRunning, label %stickyStateCheck
; ON: stickyStateCheck:
; ON: getelementptr inbounds i8, i8 addrspace(1)* %obj, i64 6
; ON: load atomic i16, i16 addrspace(1)* {{.*}} acquire, align 2
; ON: and i16 {{.*}}, 4
; ON: icmp ne i16 {{.*}}, 0
; ON: br i1 {{.*}}, label %gcNoRunning, label %gcRunning
; ON: gcNoRunning:
; ON: store i8 addrspace(1)* %value

define void @sticky_gcwrite_ref_1(i8 addrspace(1)* %obj,
                                  i8 addrspace(1)* %value,
                                  i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
entry:
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value,
                                  i8 addrspace(1)* %obj,
                                  i8 addrspace(1)* addrspace(1)* %field)
  ret void
}

define void @sticky_gcwrite_ref_2(i8 addrspace(1)* %obj,
                                  i8 addrspace(1)* %value,
                                  i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
entry:
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value,
                                  i8 addrspace(1)* %obj,
                                  i8 addrspace(1)* addrspace(1)* %field)
  ret void
}

; ON-LABEL: define void @sticky_gcwrite_struct_1
; ON: br i1 {{.*}}, label %stickySourceCheck, label %gcRunning
; ON: gcRunning:
; ON: call void @CJ_MCC_WriteStructField
; ON: stickyStateCheck:
; ON: load atomic i16, i16 addrspace(1)* {{.*}} acquire, align 2
; ON: and i16 {{.*}}, 4
; ON: br i1 {{.*}}, label %gcNoRunning, label %gcRunning
; ON: gcNoRunning:
; ON: call void @llvm.memcpy

define void @sticky_gcwrite_struct_1(i8 addrspace(1)* %obj,
                                     i8 addrspace(1)* %dst,
                                     i8* %src) gc "cangjie" {
entry:
  call void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)* %obj,
                                         i8 addrspace(1)* %dst, i8* %src,
                                         i64 8), !AggType !0
  ret void
}

define void @sticky_gcwrite_struct_2(i8 addrspace(1)* %obj,
                                     i8 addrspace(1)* %dst,
                                     i8* %src) gc "cangjie" {
entry:
  call void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)* %obj,
                                         i8 addrspace(1)* %dst, i8* %src,
                                         i64 8), !AggType !0
  ret void
}

; ON-LABEL: define void @sticky_array_copy_struct_1
; ON: br i1 {{.*}}, label %stickySourceCheck, label %gcRunning
; ON: gcRunning:
; ON: call void @CJ_MCC_ArrayCopyStruct
; ON: stickySourceCheck:
; ON: icmp eq i8 addrspace(1)* %dst.obj, null
; ON: stickyStateCheck:
; ON: load atomic i16, i16 addrspace(1)* {{.*}} acquire, align 2
; ON: and i16 {{.*}}, 4
; ON: br i1 {{.*}}, label %gcNoRunning, label %gcRunning
; ON: gcNoRunning:
; ON: call void @llvm.memmove

define void @sticky_array_copy_struct_1(i8 addrspace(1)* %dst.obj,
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

define void @sticky_array_copy_struct_2(i8 addrspace(1)* %dst.obj,
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

; ON-LABEL: define void @sticky_array_copy_ref_1
; ON: br i1 {{.*}}, label %stickySourceCheck, label %gcRunning
; ON: gcRunning:
; ON: call void @CJ_MCC_ArrayCopyRef
; ON: stickySourceCheck:
; ON: icmp eq i8 addrspace(1)* %dst.obj, null
; ON: stickyStateCheck:
; ON: load atomic i16, i16 addrspace(1)* {{.*}} acquire, align 2
; ON: and i16 {{.*}}, 4
; ON: br i1 {{.*}}, label %gcNoRunning, label %gcRunning
; ON: gcNoRunning:
; ON: call void @llvm.memmove

define void @sticky_array_copy_ref_1(i8 addrspace(1)* %dst.obj,
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

define void @sticky_array_copy_ref_2(i8 addrspace(1)* %dst.obj,
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

; ON-LABEL: define void @sticky_atomic_store_1
; ON: br i1 {{.*}}, label %stickySourceCheck, label %gcRunning
; ON: gcRunning:
; ON: call void @CJ_MCC_AtomicWriteReference{{.*}}i32 5
; ON: stickySourceCheck:
; ON: icmp eq i8 addrspace(1)* %obj, null
; ON: stickyStateCheck:
; ON: load atomic i16, i16 addrspace(1)* {{.*}} acquire, align 2
; ON: and i16 {{.*}}, 4
; ON: br i1 {{.*}}, label %gcNoRunning, label %gcRunning
; ON: gcNoRunning:
; ON: store atomic i8 addrspace(1)* %value{{.*}}seq_cst

define void @sticky_atomic_store_1(i8 addrspace(1)* %obj,
                                   i8 addrspace(1)* %value,
                                   i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
entry:
  call void @llvm.cj.atomic.store(i8 addrspace(1)* %value,
                                   i8 addrspace(1)* %obj,
                                   i8 addrspace(1)* addrspace(1)* %field,
                                   i32 5)
  ret void
}

define void @sticky_atomic_store_2(i8 addrspace(1)* %obj,
                                   i8 addrspace(1)* %value,
                                   i8 addrspace(1)* addrspace(1)* %field) gc "cangjie" {
entry:
  call void @llvm.cj.atomic.store(i8 addrspace(1)* %value,
                                   i8 addrspace(1)* %obj,
                                   i8 addrspace(1)* addrspace(1)* %field,
                                   i32 5)
  ret void
}

%StickyAgg = type { i8 addrspace(1)* }
@sticky.type.anchor = external global %StickyAgg

declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*,
                                  i8 addrspace(1)* addrspace(1)*)
declare void @llvm.cj.gcwrite.struct.p0i8(i8 addrspace(1)*,
                                         i8 addrspace(1)*, i8*, i64)
declare void @llvm.cj.array.copy.struct.i64(i8 addrspace(1)*,
                                            i8 addrspace(1)*,
                                            i8 addrspace(1)*,
                                            i8 addrspace(1)*, i64)
declare void @llvm.cj.array.copy.ref.i64(i8 addrspace(1)*,
                                         i8 addrspace(1)*,
                                         i8 addrspace(1)*,
                                         i8 addrspace(1)*, i64)
declare void @llvm.cj.atomic.store(i8 addrspace(1)*, i8 addrspace(1)*,
                                   i8 addrspace(1)* addrspace(1)*, i32)

!0 = !{!"StickyAgg"}
