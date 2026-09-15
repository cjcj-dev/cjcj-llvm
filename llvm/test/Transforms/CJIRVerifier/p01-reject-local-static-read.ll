; RUN: not --crash opt -passes=cj-ir-verifier -disable-output < %s 2>&1 | FileCheck %s
; CHECK: P01: plain local root must not use a colored static read barrier
%Local = type { i8 addrspace(1)* }
define i8 addrspace(1)* @wrong_local_read(i8 addrspace(1)* %value) gc "cangjie" {
  %local = alloca %Local, align 8
  %bytes = bitcast %Local* %local to i8*
  call void @llvm.cj.memset(i8* %bytes, i8 0, i64 8, i1 false)
  %field = getelementptr %Local, %Local* %local, i32 0, i32 0
  store i8 addrspace(1)* %value, i8 addrspace(1)** %field
  %result = call i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)** %field)
  ret i8 addrspace(1)* %result
}
declare i8 addrspace(1)* @llvm.cj.gcread.static.ref(i8 addrspace(1)**)
declare void @llvm.cj.memset(i8*, i8, i64, i1)
