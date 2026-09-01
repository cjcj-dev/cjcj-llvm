; RUN: opt -passes=cj-boxed-value-barrier -S < %s | FileCheck %s

; The exact frontend boxed-payload sequence is rewritten.
; CHECK-LABEL: define i8 addrspace(1)* @rewrite_dynamic_box(
; CHECK: %object = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* %type.info, i32 %size)
; CHECK-NEXT: %object.fields = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
; CHECK-NEXT: %payload.slot = getelementptr i8*, i8* addrspace(1)* %object.fields, i32 1
; CHECK-NEXT: %payload = bitcast i8* addrspace(1)* %payload.slot to i8 addrspace(1)*
; CHECK-NEXT: call void @llvm.cj.gcwrite.generic.payload(i8 addrspace(1)* %object, i8* %source, i32 %size)
; CHECK-NOT: llvm.memcpy
define i8 addrspace(1)* @rewrite_dynamic_box(i8* %type.info, i8* %source,
                                              i32 %size) gc "cangjie" {
entry:
  %object = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* %type.info,
                                                         i32 %size)
  %object.fields = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.slot = getelementptr i8*, i8* addrspace(1)* %object.fields, i32 1
  %payload = bitcast i8* addrspace(1)* %payload.slot to i8 addrspace(1)*
  call void @llvm.memcpy.p1i8.p0i8.i32(i8 addrspace(1)* %payload,
                                       i8* %source, i32 %size, i1 false)
  ret i8 addrspace(1)* %object
}

; An intervening call means the destination chain is not adjacent to its
; allocation.  This case is also the adjacency guard's fault-injection arm.
; CHECK-LABEL: define i8 addrspace(1)* @keep_intervening_call(
; CHECK: call void @opaque()
; CHECK-NEXT: call void @llvm.memcpy.p1i8.p0i8.i32
; CHECK-NOT: call void @llvm.cj.gcwrite.generic.payload
define i8 addrspace(1)* @keep_intervening_call(i8* %type.info, i8* %source,
                                                i32 %size) gc "cangjie" {
entry:
  %object = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* %type.info,
                                                         i32 %size)
  %object.fields = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.slot = getelementptr i8*, i8* addrspace(1)* %object.fields, i32 1
  %payload = bitcast i8* addrspace(1)* %payload.slot to i8 addrspace(1)*
  call void @opaque()
  call void @llvm.memcpy.p1i8.p0i8.i32(i8 addrspace(1)* %payload,
                                       i8* %source, i32 %size, i1 false)
  ret i8 addrspace(1)* %object
}

; alloca.generic is not excluded because it is assumed to be a stack object;
; it is excluded because this pass only repairs the malloc.object frontend
; shape.  Existing verifier acceptance relies on statically reference-free
; payload layout.
; CHECK-LABEL: define i8 addrspace(1)* @keep_alloca_generic(
; CHECK: %object = call i8 addrspace(1)* @llvm.cj.alloca.generic
; CHECK: call void @llvm.memcpy.p1i8.p0i8.i32
; CHECK-NOT: call void @llvm.cj.gcwrite.generic.payload
define i8 addrspace(1)* @keep_alloca_generic(i8* %type.info, i8* %source,
                                              i32 %size) gc "cangjie" {
entry:
  %object = call i8 addrspace(1)* @llvm.cj.alloca.generic(i8* %type.info,
                                                          i32 %size)
  %object.fields = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.slot = getelementptr i8*, i8* addrspace(1)* %object.fields, i32 1
  %payload = bitcast i8* addrspace(1)* %payload.slot to i8 addrspace(1)*
  call void @llvm.memcpy.p1i8.p0i8.i32(i8 addrspace(1)* %payload,
                                       i8* %source, i32 %size, i1 false)
  ret i8 addrspace(1)* %object
}

; Constant-size memcpy, including the common i64 overload, remains outside
; the dynamic-size repair.
; CHECK-LABEL: define i8 addrspace(1)* @keep_constant_i64(
; CHECK: call void @llvm.memcpy.p1i8.p0i8.i64
; CHECK-NOT: call void @llvm.cj.gcwrite.generic.payload
define i8 addrspace(1)* @keep_constant_i64(i8* %type.info,
                                            i8* %source) gc "cangjie" {
entry:
  %object = call i8 addrspace(1)* @llvm.cj.malloc.object(i8* %type.info,
                                                         i32 16)
  %object.fields = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.slot = getelementptr i8*, i8* addrspace(1)* %object.fields, i32 1
  %payload = bitcast i8* addrspace(1)* %payload.slot to i8 addrspace(1)*
  call void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)* %payload,
                                       i8* %source, i64 16, i1 false)
  ret i8 addrspace(1)* %object
}

; A destination loaded from memory has no local allocation proof.
; CHECK-LABEL: define void @keep_loaded_destination(
; CHECK: %destination = load i8 addrspace(1)*
; CHECK: call void @llvm.memcpy.p1i8.p0i8.i32
; CHECK-NOT: call void @llvm.cj.gcwrite.generic.payload
define void @keep_loaded_destination(i8 addrspace(1)** %slot, i8* %source,
                                     i32 %size) gc "cangjie" {
entry:
  %destination = load i8 addrspace(1)*, i8 addrspace(1)** %slot
  call void @llvm.memcpy.p1i8.p0i8.i32(i8 addrspace(1)* %destination,
                                       i8* %source, i32 %size, i1 false)
  ret void
}

; malloc.array is not a boxed-object payload allocation.
; CHECK-LABEL: define i8 addrspace(1)* @keep_malloc_array(
; CHECK: %object = call i8 addrspace(1)* @llvm.cj.malloc.array
; CHECK: call void @llvm.memcpy.p1i8.p0i8.i32
; CHECK-NOT: call void @llvm.cj.gcwrite.generic.payload
define i8 addrspace(1)* @keep_malloc_array(i8* %type.info, i8* %source,
                                            i32 %size) gc "cangjie" {
entry:
  %size.i64 = zext i32 %size to i64
  %object = call i8 addrspace(1)* @llvm.cj.malloc.array(i8* %type.info,
                                                        i64 1, i64 %size.i64)
  %object.fields = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.slot = getelementptr i8*, i8* addrspace(1)* %object.fields, i32 1
  %payload = bitcast i8* addrspace(1)* %payload.slot to i8 addrspace(1)*
  call void @llvm.memcpy.p1i8.p0i8.i32(i8 addrspace(1)* %payload,
                                       i8* %source, i32 %size, i1 false)
  ret i8 addrspace(1)* %object
}

; A synthetic source without malloc.object is the zero-match control arm.
; CHECK-LABEL: define void @keep_argument_object(
; CHECK: call void @llvm.memcpy.p1i8.p0i8.i32
; CHECK-NOT: call void @llvm.cj.gcwrite.generic.payload
define void @keep_argument_object(i8 addrspace(1)* %object, i8* %source,
                                  i32 %size) gc "cangjie" {
entry:
  %object.fields = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.slot = getelementptr i8*, i8* addrspace(1)* %object.fields, i32 1
  %payload = bitcast i8* addrspace(1)* %payload.slot to i8 addrspace(1)*
  call void @llvm.memcpy.p1i8.p0i8.i32(i8 addrspace(1)* %payload,
                                       i8* %source, i32 %size, i1 false)
  ret void
}

declare i8 addrspace(1)* @llvm.cj.malloc.object(i8*, i32)
declare i8 addrspace(1)* @llvm.cj.alloca.generic(i8*, i32)
declare i8 addrspace(1)* @llvm.cj.malloc.array(i8*, i64, i64)
declare void @llvm.memcpy.p1i8.p0i8.i32(i8 addrspace(1)*, i8*, i32, i1)
declare void @llvm.memcpy.p1i8.p0i8.i64(i8 addrspace(1)*, i8*, i64, i1)
declare void @opaque()
