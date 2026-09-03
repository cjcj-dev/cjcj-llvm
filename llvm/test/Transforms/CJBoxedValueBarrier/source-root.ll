; RUN: opt -passes=cj-boxed-value-barrier -S < %s | FileCheck %s

; A bitcast around a GEP must not hide that the source root is a load.
; CHECK-LABEL: define i8 addrspace(1)* @keep_loaded_root(
; CHECK: %base = load [1 x i8]*, [1 x i8]** %slot
; CHECK: %element = getelementptr inbounds [1 x i8], [1 x i8]* %base, i64 %index
; CHECK: %source = bitcast [1 x i8]* %element to i8*
; CHECK: call void @llvm.memcpy.p1i8.p0i8.i32
; CHECK-NOT: call void @llvm.cj.gcwrite.generic.payload
define i8 addrspace(1)* @keep_loaded_root(
    i8* %type.info, [1 x i8]** %slot, i64 %index,
    i32 %size) gc "cangjie" {
entry:
  %base = load [1 x i8]*, [1 x i8]** %slot
  %object = call i8 addrspace(1)* @llvm.cj.alloca.generic(i8* %type.info,
                                                          i32 %size)
  %object.fields = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.slot = getelementptr i8*, i8* addrspace(1)* %object.fields, i32 1
  %element = getelementptr inbounds [1 x i8], [1 x i8]* %base, i64 %index
  %source = bitcast [1 x i8]* %element to i8*
  %payload = bitcast i8* addrspace(1)* %payload.slot to i8 addrspace(1)*
  call void @llvm.memcpy.p1i8.p0i8.i32(i8 addrspace(1)* %payload,
                                       i8* %source, i32 %size, i1 false)
  ret i8 addrspace(1)* %object
}

; The same bitcast/GEP shape remains eligible when rooted in an argument.
; CHECK-LABEL: define i8 addrspace(1)* @rewrite_argument_root(
; CHECK: call void @llvm.cj.gcwrite.generic.payload(i8 addrspace(1)* %object, i8* %source, i32 %size)
; CHECK-NOT: call void @llvm.memcpy
define i8 addrspace(1)* @rewrite_argument_root(
    i8* %type.info, [1 x i8]* %source.base, i64 %index,
    i32 %size) gc "cangjie" {
entry:
  %object = call i8 addrspace(1)* @llvm.cj.alloca.generic(i8* %type.info,
                                                          i32 %size)
  %object.fields = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.slot = getelementptr i8*, i8* addrspace(1)* %object.fields, i32 1
  %element = getelementptr inbounds [1 x i8], [1 x i8]* %source.base, i64 %index
  %source = bitcast [1 x i8]* %element to i8*
  %payload = bitcast i8* addrspace(1)* %payload.slot to i8 addrspace(1)*
  call void @llvm.memcpy.p1i8.p0i8.i32(i8 addrspace(1)* %payload,
                                       i8* %source, i32 %size, i1 false)
  ret i8 addrspace(1)* %object
}

; An entry-block alloca is the other allowed root for the same shape.
; CHECK-LABEL: define i8 addrspace(1)* @rewrite_entry_alloca_root(
; CHECK: call void @llvm.cj.gcwrite.generic.payload(i8 addrspace(1)* %object, i8* %source, i32 %size)
; CHECK-NOT: call void @llvm.memcpy
define i8 addrspace(1)* @rewrite_entry_alloca_root(
    i8* %type.info, i64 %index, i32 %size) gc "cangjie" {
entry:
  %source.base = alloca [1 x i8], i64 64
  %object = call i8 addrspace(1)* @llvm.cj.alloca.generic(i8* %type.info,
                                                          i32 %size)
  %object.fields = bitcast i8 addrspace(1)* %object to i8* addrspace(1)*
  %payload.slot = getelementptr i8*, i8* addrspace(1)* %object.fields, i32 1
  %element = getelementptr inbounds [1 x i8], [1 x i8]* %source.base, i64 %index
  %source = bitcast [1 x i8]* %element to i8*
  %payload = bitcast i8* addrspace(1)* %payload.slot to i8 addrspace(1)*
  call void @llvm.memcpy.p1i8.p0i8.i32(i8 addrspace(1)* %payload,
                                       i8* %source, i32 %size, i1 false)
  ret i8 addrspace(1)* %object
}

declare i8 addrspace(1)* @llvm.cj.alloca.generic(i8*, i32)
declare void @llvm.memcpy.p1i8.p0i8.i32(i8 addrspace(1)*, i8*, i32, i1)
