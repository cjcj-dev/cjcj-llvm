; The fixed frame exceeds the default stack-check threshold; volatile stores
; keep it live. Grow/SOFE are separate flag recipes on these exact bytes.
declare token @llvm.cj.gc.statepoint(...)
declare void @CJ_MCC_StackCheck()
declare void @callee()
declare void @CJ_MCC_HandleSafepoint()
@CJ_MCC_HandleSafepoint.CJStubGV = external global i8*
define void @test() noinline optnone gc "cangjie" {
entry:
  %frame = alloca [65536 x i8], align 16
  %p = getelementptr [65536 x i8], [65536 x i8]* %frame, i64 0, i64 65535
  store volatile i8 1, i8* %p
  %check = call token (...) @llvm.cj.gc.statepoint(i64 5, i32 0, void ()* @CJ_MCC_StackCheck, i32 0, i32 0)
  call void @callee()
  %poll = call token (...) @llvm.cj.gc.statepoint(i64 3, i32 0, void ()* @CJ_MCC_HandleSafepoint, i32 0, i32 0)
  %again = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, void ()* @callee, i32 0, i32 0)
  store volatile i8 2, i8* %p
  ret void
}
!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_system"}
