; Source-stage input only; no syntax/codegen run authorized.
; optnone/noinline and distinct side effects witness two return paths.
declare void @left() "gc-leaf-function"
declare void @right() "gc-leaf-function"
define i8 addrspace(1)* @test(i1 %which, i8 addrspace(1)* %a, i8 addrspace(1)* %b) noinline optnone gc "cangjie" {
entry:
  br i1 %which, label %l, label %r
l:
  call void @left()
  ret i8 addrspace(1)* %a
r:
  call void @right()
  ret i8 addrspace(1)* %b
}
!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_system"}
