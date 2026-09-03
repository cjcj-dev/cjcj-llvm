; RUN: opt -passes=cj-boxed-value-barrier -S < %s | FileCheck %s

; An AS0 argument plus an inbounds byte GEP is a valid native source.  The
; index may be computed through arbitrary i64 SSA (including a phi).
; CHECK-LABEL: define i8 addrspace(1)* @rewrite_argument_element(
; CHECK: %index.phi = phi i64 [ %index, %then ], [ %index.alt, %else ]
; CHECK: %element = getelementptr inbounds i8, i8* %source.base, i64 %index.phi
; CHECK: call void @llvm.cj.gcwrite.generic.payload(i8 addrspace(1)* %object, i8* %element, i32 %size)
; CHECK-NOT: call void @llvm.memcpy
define i8 addrspace(1)* @rewrite_argument_element(
    i8* %type.info, i8* %source.base, i1 %cond, i64 %index,
    i64 %index.alt, i32 %size) gc "cangjie" {
entry:
  br i1 %cond, label %then, label %else
then:
  br label %merge
else:
  br label %merge
merge:
  %index.phi = phi i64 [ %index, %then ], [ %index.alt, %else ]
  %object = call i8 addrspace(1)* @llvm.cj.alloca.generic(i8* %type.info,
                                                          i32 %size)
  %object.fields = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.slot = getelementptr i8*, i8* addrspace(1)* %object.fields, i32 1
  %element = getelementptr inbounds i8, i8* %source.base, i64 %index.phi
  %payload = bitcast i8* addrspace(1)* %payload.slot to i8 addrspace(1)*
  call void @llvm.memcpy.p1i8.p0i8.i32(i8 addrspace(1)* %payload,
                                       i8* %element, i32 %size, i1 false)
  ret i8 addrspace(1)* %object
}

; An entry-block alloca is also a valid AS0 root.
; CHECK-LABEL: define i8 addrspace(1)* @rewrite_entry_alloca_element(
; CHECK: %index.ext = zext i32 %index to i64
; CHECK: %index.mul = mul i64 %index.ext, 4
; CHECK: %element = getelementptr inbounds i8, i8* %stack, i64 %index.mul
; CHECK: call void @llvm.cj.gcwrite.generic.payload(i8 addrspace(1)* %object, i8* %element, i32 %size)
; CHECK-NOT: call void @llvm.memcpy
define i8 addrspace(1)* @rewrite_entry_alloca_element(
    i8* %type.info, i32 %index, i32 %size) gc "cangjie" {
entry:
  %stack = alloca i8, i64 64
  %index.ext = zext i32 %index to i64
  %index.mul = mul i64 %index.ext, 4
  %object = call i8 addrspace(1)* @llvm.cj.alloca.generic(i8* %type.info,
                                                          i32 %size)
  %object.fields = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.slot = getelementptr i8*, i8* addrspace(1)* %object.fields, i32 1
  %element = getelementptr inbounds i8, i8* %stack, i64 %index.mul
  %payload = bitcast i8* addrspace(1)* %payload.slot to i8 addrspace(1)*
  call void @llvm.memcpy.p1i8.p0i8.i32(i8 addrspace(1)* %payload,
                                       i8* %element, i32 %size, i1 false)
  ret i8 addrspace(1)* %object
}

; A loaded AS0 base is not a local native root and remains untouched.
; CHECK-LABEL: define i8 addrspace(1)* @keep_loaded_element(
; CHECK: %base = load i8*, i8** %slot
; CHECK: %element = getelementptr inbounds i8, i8* %base, i64 %index
; CHECK: call void @llvm.memcpy.p1i8.p0i8.i32
; CHECK-NOT: call void @llvm.cj.gcwrite.generic.payload
define i8 addrspace(1)* @keep_loaded_element(
    i8* %type.info, i8** %slot, i64 %index, i32 %size) gc "cangjie" {
entry:
  %base = load i8*, i8** %slot
  %object = call i8 addrspace(1)* @llvm.cj.alloca.generic(i8* %type.info,
                                                          i32 %size)
  %object.fields = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.slot = getelementptr i8*, i8* addrspace(1)* %object.fields, i32 1
  %element = getelementptr inbounds i8, i8* %base, i64 %index
  %payload = bitcast i8* addrspace(1)* %payload.slot to i8 addrspace(1)*
  call void @llvm.memcpy.p1i8.p0i8.i32(i8 addrspace(1)* %payload,
                                       i8* %element, i32 %size, i1 false)
  ret i8 addrspace(1)* %object
}

; The source GEP is valid, but a different copy length does not satisfy the
; allocation-size == copy-length invariant.
; CHECK-LABEL: define i8 addrspace(1)* @keep_element_size_mismatch(
; CHECK: %element = getelementptr inbounds i8, i8* %source.base, i64 %index
; CHECK: call void @llvm.memcpy.p1i8.p0i8.i32
; CHECK-NOT: call void @llvm.cj.gcwrite.generic.payload
define i8 addrspace(1)* @keep_element_size_mismatch(
    i8* %type.info, i8* %source.base, i64 %index,
    i32 %allocation.size, i32 %copy.length) gc "cangjie" {
entry:
  %object = call i8 addrspace(1)* @llvm.cj.alloca.generic(
      i8* %type.info, i32 %allocation.size)
  %object.fields = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.slot = getelementptr i8*, i8* addrspace(1)* %object.fields, i32 1
  %element = getelementptr inbounds i8, i8* %source.base, i64 %index
  %payload = bitcast i8* addrspace(1)* %payload.slot to i8 addrspace(1)*
  call void @llvm.memcpy.p1i8.p0i8.i32(i8 addrspace(1)* %payload,
                                       i8* %element, i32 %copy.length, i1 false)
  ret i8 addrspace(1)* %object
}

declare i8 addrspace(1)* @llvm.cj.alloca.generic(i8*, i32)
declare void @llvm.memcpy.p1i8.p0i8.i32(i8 addrspace(1)*, i8*, i32, i1)
