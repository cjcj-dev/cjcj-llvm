declare token @llvm.cj.gc.statepoint(...)
declare void @CJ_MCC_ThrowException(i8 addrspace(1)*)
define void @test(i8 addrspace(1)* %exception)  gc "cangjie" {
%s = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, void (i8 addrspace(1)*)* @CJ_MCC_ThrowException, i32 1, i32 0, i8 addrspace(1)* %exception)
unreachable
}

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_p0"}
