; StatepointLowering.cpp:1300-1318 requires a direct callee for machine-tail
; selection. This IR tail hint is a call control, not a JMP oracle.
declare token @llvm.experimental.gc.statepoint.p0f_isVoidf(i64, i32, void ()*, i32, i32, ...)
define void @test(void ()* %fp) gc "cangjie" {
  %s = tail call token (i64, i32, void ()*, i32, i32, ...) @llvm.experimental.gc.statepoint.p0f_isVoidf(i64 0, i32 0, void ()* elementtype(void ()) %fp, i32 0, i32 0, i32 0, i32 0)
  ret void
}
!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_system"}
