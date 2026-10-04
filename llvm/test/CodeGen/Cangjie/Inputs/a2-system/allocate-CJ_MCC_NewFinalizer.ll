declare token @llvm.cj.gc.statepoint(...)
declare i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8*, i32)
declare i8 addrspace(1)* @CJ_MCC_OnFinalizerCreated(i8 addrspace(1)*)
define void @test(i8* %ti)  gc "cangjie" {
%s = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i32)* @CJ_MCC_NewFinalizer, i32 2, i32 0, i8* %ti, i32 32)
ret void
}

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_p0"}
