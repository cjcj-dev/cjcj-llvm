declare void @callee()
declare void @other()
declare token @llvm.experimental.gc.statepoint.p0f_isVoidf(i64, i32, void ()*, i32, i32, ...)
declare i32 addrspace(1)* @llvm.experimental.gc.relocate.p1i32(token, i32, i32)
define i32 addrspace(1)* @test(i32 addrspace(1)* %root)  gc "cangjie" {
%s = call token (i64, i32, void ()*, i32, i32, ...) @llvm.experimental.gc.statepoint.p0f_isVoidf(i64 0, i32 0, void ()* elementtype(void ()) @callee, i32 0, i32 0, i32 0, i32 0) ["gc-live"(i32 addrspace(1)* %root)]
%r = call i32 addrspace(1)* @llvm.experimental.gc.relocate.p1i32(token %s, i32 0, i32 0)
ret i32 addrspace(1)* %r
}

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_p0"}
