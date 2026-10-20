; Typed instructions; not .inst bytes. Calls have no fabricated root graph.
define void @test() noinline optnone gc "cangjie" {
  call void asm sideeffect "1: bl callee; sub sp, sp, #16; bl other; add sp, sp, #16; cbnz x0, 1b", "~{sp},~{x30},~{memory}"() #0
  ret void
}
attributes #0 = { "gc-leaf-function" }
!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_system"}
