; RUN: llc -mtriple=x86_64-w64-mingw32 --cangjie-pipeline -filetype=obj -o %t.obj %s
; RUN: llvm-readobj --sections %t.obj | FileCheck %s

@type.ext = internal global i64 0 #0
@llvm.used = appending global [1 x i8*] [i8* bitcast (i64* @type.ext to i8*)], section "llvm.metadata"

attributes #0 = { "CFileTIExt" }

; CHECK: Name: .cjtpe
