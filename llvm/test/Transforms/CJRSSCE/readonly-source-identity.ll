; RUN: opt -passes=cj-rssce -S < %s | FileCheck %s

%record.test1 = type {i8 addrspace(1)*, i64, i64}
%record.test2 = type {i64, i8 addrspace(1)*, i64}

declare void @func1(%record.test1*) #0
declare void @llvm.memcpy.p0i8.p1i8.i64(i8* noalias nocapture writeonly, i8 addrspace(1)* noalias nocapture readonly, i64, i1 immarg)
declare void @init_record1(%record.test1* %ptr)
declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* nocapture, i8 addrspace(1)* addrspace(1)* nocapture)

declare void @mutate(%record.test2*)

; CHECK-LABEL: define void @loaded_source_clean()
; CHECK: [[CAST:%.*]] = addrspacecast i8 addrspace(1)* {{%.*}} to i8*
; CHECK-NEXT: [[PTR:%.*]] = bitcast i8* [[CAST]] to %record.test1*
; CHECK-NEXT: call void @func1(%record.test1* [[PTR]])
define void @loaded_source_clean() {
entry:
  %0 = alloca %record.test1, align 8
  %1 = alloca %record.test1, align 8
  %2 = alloca %record.test2, align 8
  call void @init_record1(%record.test1* %1)
  %3 = addrspacecast %record.test1* %1 to %record.test1 addrspace(1)*
  %4 = bitcast %record.test1 addrspace(1)* %3 to i8 addrspace(1)*
  %5 = getelementptr inbounds %record.test2, %record.test2* %2, i32 0, i32 1
  store i8 addrspace(1)* %4, i8 addrspace(1)** %5, align 8
  call void @init_record1(%record.test1* %0)
  %6 = getelementptr inbounds %record.test2, %record.test2* %2, i32 0, i32 1
  %7 = load i8 addrspace(1)*, i8 addrspace(1)** %6, align 8
  %8 = getelementptr inbounds i8, i8 addrspace(1)* %7, i32 0
  %9 = bitcast i8 addrspace(1)* %8 to i8 addrspace(1)* addrspace(1)*
  %10 = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %7, i8 addrspace(1)* addrspace(1)* %9)
  %11 = getelementptr inbounds %record.test1, %record.test1* %0, i32 0, i32 0
  store i8 addrspace(1)* %10, i8 addrspace(1)** %11, align 8
  %12 = getelementptr inbounds %record.test1, %record.test1* %0, i32 0, i32 1
  %13 = bitcast i64* %12 to i8*
  %14 = getelementptr inbounds i8, i8 addrspace(1)* %7, i32 8
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %13, i8 addrspace(1)* %14, i64 16, i1 false)
  call void @func1(%record.test1* %0)
  ret void
}


; CHECK-LABEL: define void @loaded_source_changed()
; CHECK: call void @func1(%record.test1* %0)
define void @loaded_source_changed() {
entry:
  %0 = alloca %record.test1, align 8
  %1 = alloca %record.test1, align 8
  %2 = alloca %record.test2, align 8
  call void @init_record1(%record.test1* %1)
  %3 = addrspacecast %record.test1* %1 to %record.test1 addrspace(1)*
  %4 = bitcast %record.test1 addrspace(1)* %3 to i8 addrspace(1)*
  %5 = getelementptr inbounds %record.test2, %record.test2* %2, i32 0, i32 1
  store i8 addrspace(1)* %4, i8 addrspace(1)** %5, align 8
  call void @init_record1(%record.test1* %0)
  %6 = getelementptr inbounds %record.test2, %record.test2* %2, i32 0, i32 1
  %7 = load i8 addrspace(1)*, i8 addrspace(1)** %6, align 8
  %8 = getelementptr inbounds i8, i8 addrspace(1)* %7, i32 0
  %9 = bitcast i8 addrspace(1)* %8 to i8 addrspace(1)* addrspace(1)*
  %10 = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %7, i8 addrspace(1)* addrspace(1)* %9)
  %11 = getelementptr inbounds %record.test1, %record.test1* %0, i32 0, i32 0
  store i8 addrspace(1)* %10, i8 addrspace(1)** %11, align 8
  store i8 addrspace(1)* null, i8 addrspace(1)* addrspace(1)* %9, align 8
  %12 = getelementptr inbounds %record.test1, %record.test1* %0, i32 0, i32 1
  %13 = bitcast i64* %12 to i8*
  %14 = getelementptr inbounds i8, i8 addrspace(1)* %7, i32 8
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %13, i8 addrspace(1)* %14, i64 16, i1 false)
  call void @func1(%record.test1* %0)
  ret void
}


; CHECK-LABEL: define void @pointer_slot_unknown()
; CHECK: call void @func1(%record.test1* %0)
define void @pointer_slot_unknown() {
entry:
  %0 = alloca %record.test1, align 8
  %1 = alloca %record.test1, align 8
  %2 = alloca %record.test2, align 8
  call void @init_record1(%record.test1* %1)
  %3 = addrspacecast %record.test1* %1 to %record.test1 addrspace(1)*
  %4 = bitcast %record.test1 addrspace(1)* %3 to i8 addrspace(1)*
  %5 = getelementptr inbounds %record.test2, %record.test2* %2, i32 0, i32 1
  store i8 addrspace(1)* %4, i8 addrspace(1)** %5, align 8
  call void @init_record1(%record.test1* %0)
  call void @mutate(%record.test2* %2)
  %6 = getelementptr inbounds %record.test2, %record.test2* %2, i32 0, i32 1
  %7 = load i8 addrspace(1)*, i8 addrspace(1)** %6, align 8
  %8 = getelementptr inbounds i8, i8 addrspace(1)* %7, i32 0
  %9 = bitcast i8 addrspace(1)* %8 to i8 addrspace(1)* addrspace(1)*
  %10 = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %7, i8 addrspace(1)* addrspace(1)* %9)
  %11 = getelementptr inbounds %record.test1, %record.test1* %0, i32 0, i32 0
  store i8 addrspace(1)* %10, i8 addrspace(1)** %11, align 8
  %12 = getelementptr inbounds %record.test1, %record.test1* %0, i32 0, i32 1
  %13 = bitcast i64* %12 to i8*
  %14 = getelementptr inbounds i8, i8 addrspace(1)* %7, i32 8
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %13, i8 addrspace(1)* %14, i64 16, i1 false)
  call void @func1(%record.test1* %0)
  ret void
}


; CHECK-LABEL: define void @pointer_slot_volatile_load()
; CHECK: call void @func1(%record.test1* %0)
define void @pointer_slot_volatile_load() {
entry:
  %0 = alloca %record.test1, align 8
  %1 = alloca %record.test1, align 8
  %2 = alloca %record.test2, align 8
  call void @init_record1(%record.test1* %1)
  %3 = addrspacecast %record.test1* %1 to %record.test1 addrspace(1)*
  %4 = bitcast %record.test1 addrspace(1)* %3 to i8 addrspace(1)*
  %5 = getelementptr inbounds %record.test2, %record.test2* %2, i32 0, i32 1
  store i8 addrspace(1)* %4, i8 addrspace(1)** %5, align 8
  call void @init_record1(%record.test1* %0)
  %6 = getelementptr inbounds %record.test2, %record.test2* %2, i32 0, i32 1
  %7 = load volatile i8 addrspace(1)*, i8 addrspace(1)** %6, align 8
  %8 = getelementptr inbounds i8, i8 addrspace(1)* %7, i32 0
  %9 = bitcast i8 addrspace(1)* %8 to i8 addrspace(1)* addrspace(1)*
  %10 = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %7, i8 addrspace(1)* addrspace(1)* %9)
  %11 = getelementptr inbounds %record.test1, %record.test1* %0, i32 0, i32 0
  store i8 addrspace(1)* %10, i8 addrspace(1)** %11, align 8
  %12 = getelementptr inbounds %record.test1, %record.test1* %0, i32 0, i32 1
  %13 = bitcast i64* %12 to i8*
  %14 = getelementptr inbounds i8, i8 addrspace(1)* %7, i32 8
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %13, i8 addrspace(1)* %14, i64 16, i1 false)
  call void @func1(%record.test1* %0)
  ret void
}


; CHECK-LABEL: define void @pointer_slot_atomic_store()
; CHECK: call void @func1(%record.test1* %0)
define void @pointer_slot_atomic_store() {
entry:
  %0 = alloca %record.test1, align 8
  %1 = alloca %record.test1, align 8
  %2 = alloca %record.test2, align 8
  call void @init_record1(%record.test1* %1)
  %3 = addrspacecast %record.test1* %1 to %record.test1 addrspace(1)*
  %4 = bitcast %record.test1 addrspace(1)* %3 to i8 addrspace(1)*
  %5 = getelementptr inbounds %record.test2, %record.test2* %2, i32 0, i32 1
  store i8 addrspace(1)* %4, i8 addrspace(1)** %5, align 8
  call void @init_record1(%record.test1* %0)
  store atomic i8 addrspace(1)* %4, i8 addrspace(1)** %5 monotonic, align 8
  %6 = getelementptr inbounds %record.test2, %record.test2* %2, i32 0, i32 1
  %7 = load i8 addrspace(1)*, i8 addrspace(1)** %6, align 8
  %8 = getelementptr inbounds i8, i8 addrspace(1)* %7, i32 0
  %9 = bitcast i8 addrspace(1)* %8 to i8 addrspace(1)* addrspace(1)*
  %10 = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %7, i8 addrspace(1)* addrspace(1)* %9)
  %11 = getelementptr inbounds %record.test1, %record.test1* %0, i32 0, i32 0
  store i8 addrspace(1)* %10, i8 addrspace(1)** %11, align 8
  %12 = getelementptr inbounds %record.test1, %record.test1* %0, i32 0, i32 1
  %13 = bitcast i64* %12 to i8*
  %14 = getelementptr inbounds i8, i8 addrspace(1)* %7, i32 8
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %13, i8 addrspace(1)* %14, i64 16, i1 false)
  call void @func1(%record.test1* %0)
  ret void
}


; CHECK-LABEL: define void @pointer_slot_disjoint()
; CHECK: [[CAST:%.*]] = addrspacecast i8 addrspace(1)* {{%.*}} to i8*
; CHECK-NEXT: [[PTR:%.*]] = bitcast i8* [[CAST]] to %record.test1*
; CHECK-NEXT: call void @func1(%record.test1* [[PTR]])
define void @pointer_slot_disjoint() {
entry:
  %0 = alloca %record.test1, align 8
  %1 = alloca %record.test1, align 8
  %2 = alloca %record.test2, align 8
  call void @init_record1(%record.test1* %1)
  %3 = addrspacecast %record.test1* %1 to %record.test1 addrspace(1)*
  %4 = bitcast %record.test1 addrspace(1)* %3 to i8 addrspace(1)*
  %5 = getelementptr inbounds %record.test2, %record.test2* %2, i32 0, i32 1
  store i8 addrspace(1)* %4, i8 addrspace(1)** %5, align 8
  call void @init_record1(%record.test1* %0)
  %slot = getelementptr inbounds %record.test2, %record.test2* %2, i64 0, i32 0
  store i64 17, i64* %slot, align 8
  %6 = getelementptr inbounds %record.test2, %record.test2* %2, i32 0, i32 1
  %7 = load i8 addrspace(1)*, i8 addrspace(1)** %6, align 8
  %8 = getelementptr inbounds i8, i8 addrspace(1)* %7, i32 0
  %9 = bitcast i8 addrspace(1)* %8 to i8 addrspace(1)* addrspace(1)*
  %10 = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %7, i8 addrspace(1)* addrspace(1)* %9)
  %11 = getelementptr inbounds %record.test1, %record.test1* %0, i32 0, i32 0
  store i8 addrspace(1)* %10, i8 addrspace(1)** %11, align 8
  %12 = getelementptr inbounds %record.test1, %record.test1* %0, i32 0, i32 1
  %13 = bitcast i64* %12 to i8*
  %14 = getelementptr inbounds i8, i8 addrspace(1)* %7, i32 8
  call void @llvm.memcpy.p0i8.p1i8.i64(i8* %13, i8 addrspace(1)* %14, i64 16, i1 false)
  call void @func1(%record.test1* %0)
  ret void
}


attributes #0 = { readonly }
