declare void @callee()
declare void @other()
define void @test(void ()* %fp)  gc "cangjie" {
call void asm sideeffect "bl callee", "~{x30}"() #0
ret void
}
attributes #0 = { "gc-leaf-function" }

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_p0"}
