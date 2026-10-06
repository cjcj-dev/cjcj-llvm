declare token @llvm.cj.gc.statepoint(...)
declare void @CJ_MCC_StackCheck()
define void @test(void ()* %fp)  gc "cangjie" {
%s = call token (...) @llvm.cj.gc.statepoint(i64 5, i32 0, void ()* @CJ_MCC_StackCheck, i32 0, i32 0)
ret void
}

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_p0"}
