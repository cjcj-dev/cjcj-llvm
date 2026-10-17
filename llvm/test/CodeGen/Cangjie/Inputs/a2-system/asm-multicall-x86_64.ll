; Declared frame effects clear must-state before any asm-owned call.
; The local backedge also tests region-wide invalidation of early sites.
define void @test() noinline optnone gc "cangjie" {
  call void asm sideeffect "1: callq callee; pushq %rax; callq other; popq %rax; testq %rax, %rax; jne 1b", "~{rsp},~{memory},~{dirflag},~{fpsr},~{flags}"() #0
  ret void
}
attributes #0 = { "gc-leaf-function" }
!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_system"}
