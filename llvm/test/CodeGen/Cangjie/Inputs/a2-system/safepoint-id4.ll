declare token @llvm.cj.gc.statepoint(...)
declare void @CJ_Safepoint_Stub()
@CJ_MCC_HandleSafepoint.CJStubGV = external global i8*
define void @test(void ()* %fp)  gc "cangjie" {
%s = call token (...) @llvm.cj.gc.statepoint(i64 4, i32 0, void ()* @CJ_Safepoint_Stub, i32 0, i32 0)
ret void
}

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_p0"}
