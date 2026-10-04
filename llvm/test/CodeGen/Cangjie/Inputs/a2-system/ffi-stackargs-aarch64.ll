declare token @llvm.cj.gc.statepoint(...)
declare !CallFrameSizeForCJFFI !1 void @native(i64, i64, i64, i64, i64, i64, i64, i64, i64, i64) "cj2c"
declare void @CJ_MCC_C2NStub()
@native.CJStubGV = external global i8*
define void @test() gc "cangjie" {
  %s = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, void (i64, i64, i64, i64, i64, i64, i64, i64, i64, i64)* @native, i32 10, i32 0, i64 1, i64 2, i64 3, i64 4, i64 5, i64 6, i64 7, i64 8, i64 9, i64 10)
  ret void
}
!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_system"}
!1 = !{i64 16}
