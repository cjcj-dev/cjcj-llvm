; RUN: opt -passes=cj-ir-verifier < %s -disable-output

%inner = type { i8 addrspace(1)*, i64 }
%outer = type { i64, %inner, i64 }

; A complete typed source may target a nested field of an entry-block struct
; alloca.  The destination field is covered by the statepoint registration
; contract and is admitted by the independent subobject path.
define void @allow_registered_nested_struct_subobject() gc "cangjie" {
entry:
  %dst = alloca %outer, align 8
  %src = alloca %inner, align 8
  %dst.i8 = bitcast %outer* %dst to i8*
  %src.i8 = bitcast %inner* %src to i8*
  %dst.inner = getelementptr inbounds %outer, %outer* %dst, i32 0, i32 1
  %dst.inner.i8 = bitcast %inner* %dst.inner to i8*
  call void @llvm.cj.memset(i8* %dst.i8, i8 0, i64 32, i1 false)
  call void @llvm.cj.memset(i8* %src.i8, i8 0, i64 16, i1 false)
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %dst.inner.i8, i8* %src.i8,
                                       i64 16, i1 false)
  ret void
}

declare void @llvm.cj.memset(i8*, i8, i64, i1)
declare void @llvm.memcpy.p0i8.p0i8.i64(i8*, i8*, i64, i1)
