; Balanced SP change is not a declared escaping clobber. The real save point
; is between push/pop, so the parser's physical effects must clear FULL.
define void @test() gc "cangjie" {
  call void asm sideeffect "pushq %rax; callq callee; popq %rax", "~{r11},~{memory},~{dirflag},~{fpsr},~{flags}"() #0
  ret void
}
attributes #0 = { "gc-leaf-function" }
!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_system"}
