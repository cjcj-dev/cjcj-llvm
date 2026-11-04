; A target live across another call must survive RA and the epilogue.
; This module is shared by X86 and AArch64 target regressions.
declare void @clobber()
declare void @direct_callee()
declare void @cj2c_callee() "cj2c"
declare void @c2cj_callee() "c2cj"
declare token @llvm.experimental.gc.statepoint.p0(i64, i32, ptr, i32, i32, ...)
declare i64 @llvm.experimental.gc.result.i64(token)
declare ptr addrspace(1) @llvm.experimental.gc.relocate.p1(token, i32, i32)

define void @indirect_pressure(ptr %callee, i64 %a, i64 %b, i64 %c, i64 %d, i64 %e, i64 %f) noinline gc "cangjie" {
  call void @clobber()
  %s = tail call token (i64, i32, ptr, i32, i32, ...) @llvm.experimental.gc.statepoint.p0(i64 123, i32 0, ptr elementtype(void (i64, i64, i64, i64, i64, i64)) %callee, i32 6, i32 0, i64 %a, i64 %b, i64 %c, i64 %d, i64 %e, i64 %f, i32 0, i32 0)
  ret void
}
define void @indirect_bti(ptr %callee, i64 %a, i64 %b, i64 %c, i64 %d, i64 %e, i64 %f) noinline "branch-target-enforcement"="true" gc "cangjie" {
  call void @clobber()
  %s = tail call token (i64, i32, ptr, i32, i32, ...) @llvm.experimental.gc.statepoint.p0(i64 123, i32 0, ptr elementtype(void (i64, i64, i64, i64, i64, i64)) %callee, i32 6, i32 0, i64 %a, i64 %b, i64 %c, i64 %d, i64 %e, i64 %f, i32 0, i32 0)
  ret void
}
define void @indirect_zero(ptr %callee) gc "cangjie" {
  %s = tail call token (i64, i32, ptr, i32, i32, ...) @llvm.experimental.gc.statepoint.p0(i64 123, i32 0, ptr elementtype(void ()) %callee, i32 0, i32 0, i32 0, i32 0)
  ret void
}
define void @direct_control() gc "cangjie" {
  %s = tail call token (i64, i32, ptr, i32, i32, ...) @llvm.experimental.gc.statepoint.p0(i64 123, i32 0, ptr elementtype(void ()) @direct_callee, i32 0, i32 0, i32 0, i32 0)
  ret void
}
