; Existing ID4 graph records all register roots and reserved kind2, even though
; the NOP region is not a hardware call or a managed-runtime qualification.
declare token @llvm.cj.gc.statepoint(...)
declare void @CJ_MCC_HandleSafepoint()
define void @test() gc "cangjie" {
  %s = call token (...) @llvm.cj.gc.statepoint(i64 4, i32 3, void ()* @CJ_MCC_HandleSafepoint, i32 0, i32 0)
  ret void
}
!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_system"}
