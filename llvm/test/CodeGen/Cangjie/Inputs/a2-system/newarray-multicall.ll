declare token @llvm.cj.gc.statepoint(...)
declare i8 addrspace(1)* @CJ_MCC_NewArray(i8*, i64)
declare void @callee()
define void @test(i8* %ti, i64 %length) noinline optnone gc "cangjie" {
  call void @callee()
  %array = call token (...) @llvm.cj.gc.statepoint(i64 6, i32 0, i8 addrspace(1)* (i8*, i64)* @CJ_MCC_NewArray, i32 2, i32 0, i8* %ti, i64 %length)
  call void @callee()
  ret void
}
!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_system"}
