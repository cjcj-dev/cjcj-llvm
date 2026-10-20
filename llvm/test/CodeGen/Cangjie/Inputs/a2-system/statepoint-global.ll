declare void @callee()
declare void @other()
declare token @llvm.experimental.gc.statepoint.p0f_isVoidf(i64, i32, void ()*, i32, i32, ...)
define void @test(void ()* %fp)  gc "cangjie" {
%s = call token (i64, i32, void ()*, i32, i32, ...) @llvm.experimental.gc.statepoint.p0f_isVoidf(i64 0, i32 0, void ()* elementtype(void ()) @callee, i32 0, i32 0, i32 0, i32 0)
ret void
}

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_p0"}
