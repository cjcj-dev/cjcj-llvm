; RUN: llc -O0 -cangjie-pipeline -mtriple=x86_64-pc-linux-gnu -filetype=obj %s -o %t.o
; RUN: %python %S/Inputs/check-cj-register-map.py %t.o 1
; RUN: llc -O2 -cangjie-pipeline -mtriple=x86_64-pc-linux-gnu -filetype=obj %s -o %t.opt.o
; RUN: %python %S/Inputs/check-cj-register-map.py %t.opt.o 1
; Scalar AS1 return roots use RAX. Widening the bitmap must retain this low bit.
define i8 addrspace(1)* @return_root(i8 addrspace(1)* %root) gc "cangjie" {
  ret i8 addrspace(1)* %root
}
