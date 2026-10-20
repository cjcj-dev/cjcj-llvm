; Physical SP effect, restored before leaving the asm body, but not at BL.
define void @test() gc "cangjie" {
  call void asm sideeffect "sub sp, sp, #16; bl callee; add sp, sp, #16", "~{x30},~{memory}"() #0
  ret void
}
attributes #0 = { "gc-leaf-function" }
!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_system"}
