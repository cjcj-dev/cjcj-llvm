define void @test(void ()* %fp) naked gc "cangjie" {
call void asm sideeffect "", ""()
ret void
}

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_p0"}
