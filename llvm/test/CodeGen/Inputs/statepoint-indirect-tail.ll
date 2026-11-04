; A target live across another call must survive RA and the epilogue.
; This module is shared by X86 and AArch64 target regressions.
declare void @clobber()
declare void @direct_callee()
declare void @cj2c_callee() "cj2c"
declare void @c2cj_callee() "c2cj"
declare token @llvm.experimental.gc.statepoint.p0(i64, i32, ptr, i32, i32, ...)
declare i64 @llvm.experimental.gc.result.i64(token)
declare ptr addrspace(1) @llvm.experimental.gc.relocate.p1(token, i32, i32)

define void @indirect_pressure(ptr %callee, i64 %a, i64 %b, i64 %c, i64 %d, i64 %e, i64 %f) noinline gc "statepoint-example" {
  call void @clobber()
  %s = tail call token (i64, i32, ptr, i32, i32, ...) @llvm.experimental.gc.statepoint.p0(i64 123, i32 0, ptr elementtype(void (i64, i64, i64, i64, i64, i64)) %callee, i32 6, i32 0, i64 %a, i64 %b, i64 %c, i64 %d, i64 %e, i64 %f, i32 0, i32 0)
  ret void
}
define void @indirect_bti(ptr %callee, i64 %a, i64 %b, i64 %c, i64 %d, i64 %e, i64 %f) noinline "branch-target-enforcement"="true" gc "statepoint-example" {
  call void @clobber()
  %s = tail call token (i64, i32, ptr, i32, i32, ...) @llvm.experimental.gc.statepoint.p0(i64 123, i32 0, ptr elementtype(void (i64, i64, i64, i64, i64, i64)) %callee, i32 6, i32 0, i64 %a, i64 %b, i64 %c, i64 %d, i64 %e, i64 %f, i32 0, i32 0)
  ret void
}
define void @indirect_zero(ptr %callee) gc "statepoint-example" {
  %s = tail call token (i64, i32, ptr, i32, i32, ...) @llvm.experimental.gc.statepoint.p0(i64 123, i32 0, ptr elementtype(void ()) %callee, i32 0, i32 0, i32 0, i32 0)
  ret void
}
define void @direct_control() gc "statepoint-example" {
  %s = tail call token (i64, i32, ptr, i32, i32, ...) @llvm.experimental.gc.statepoint.p0(i64 123, i32 0, ptr elementtype(void ()) @direct_callee, i32 0, i32 0, i32 0, i32 0)
  ret void
}
define void @patch_fallback(ptr %callee) gc "statepoint-example" {
  %s = tail call token (i64, i32, ptr, i32, i32, ...) @llvm.experimental.gc.statepoint.p0(i64 123, i32 16, ptr elementtype(void ()) %callee, i32 0, i32 0, i32 0, i32 0)
  ret void
}
define void @nonvoid_fallback(ptr %callee) gc "statepoint-example" {
  %s = tail call token (i64, i32, ptr, i32, i32, ...) @llvm.experimental.gc.statepoint.p0(i64 123, i32 0, ptr elementtype(i64 ()) %callee, i32 0, i32 0, i32 0, i32 0)
  ret void
}
define void @relocate_fallback(ptr %callee, ptr addrspace(1) %obj, ptr %out) gc "statepoint-example" {
  %s = tail call token (i64, i32, ptr, i32, i32, ...) @llvm.experimental.gc.statepoint.p0(i64 123, i32 0, ptr elementtype(void ()) %callee, i32 0, i32 0, i32 0, i32 0) ["gc-live" (ptr addrspace(1) %obj)]
  %r = call ptr addrspace(1) @llvm.experimental.gc.relocate.p1(token %s, i32 0, i32 0)
  store ptr addrspace(1) %r, ptr %out
  ret void
}
define void @stack_fallback(ptr %callee) gc "statepoint-example" {
  %s = tail call token (i64, i32, ptr, i32, i32, ...) @llvm.experimental.gc.statepoint.p0(i64 123, i32 0, ptr elementtype(void (i64, i64, i64, i64, i64, i64, i64, i64, i64)) %callee, i32 9, i32 0, i64 1, i64 2, i64 3, i64 4, i64 5, i64 6, i64 7, i64 8, i64 9, i32 0, i32 0)
  ret void
}
define void @cj2c_fallback() gc "statepoint-example" {
  %s = tail call token (i64, i32, ptr, i32, i32, ...) @llvm.experimental.gc.statepoint.p0(i64 123, i32 0, ptr elementtype(void ()) @cj2c_callee, i32 0, i32 0, i32 0, i32 0)
  ret void
}
define void @c2cj_fallback() "cjstub" gc "statepoint-example" {
  %s = tail call token (i64, i32, ptr, i32, i32, ...) @llvm.experimental.gc.statepoint.p0(i64 123, i32 0, ptr elementtype(void ()) @c2cj_callee, i32 0, i32 0, i32 0, i32 0)
  ret void
}
define void @not_tail(ptr %callee) gc "statepoint-example" {
  %s = call token (i64, i32, ptr, i32, i32, ...) @llvm.experimental.gc.statepoint.p0(i64 123, i32 0, ptr elementtype(void ()) %callee, i32 0, i32 0, i32 0, i32 0)
  ret void
}
define void @disabled_fallback(ptr %callee) "disable-tail-calls"="true" gc "statepoint-example" {
  %s = tail call token (i64, i32, ptr, i32, i32, ...) @llvm.experimental.gc.statepoint.p0(i64 123, i32 0, ptr elementtype(void ()) %callee, i32 0, i32 0, i32 0, i32 0)
  ret void
}
