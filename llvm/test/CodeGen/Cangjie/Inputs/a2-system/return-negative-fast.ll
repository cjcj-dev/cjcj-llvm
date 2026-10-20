define void @test(void ()* %fp) "cj_fast_call" gc "cangjie" {
ret void
}

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_p0"}
