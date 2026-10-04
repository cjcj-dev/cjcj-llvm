module asm ".byte 0x90"
define void @test(void ()* %fp)  {
ret void
}

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_p0"}
