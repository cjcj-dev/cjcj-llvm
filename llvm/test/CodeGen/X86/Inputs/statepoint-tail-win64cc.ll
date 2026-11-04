declare token @llvm.experimental.gc.statepoint.p0(i64, i32, ptr, i32, i32, ...)
define win64cc void @win64cc_zero(ptr %callee) gc "statepoint-example" {
 %s = tail call win64cc token (i64, i32, ptr, i32, i32, ...) @llvm.experimental.gc.statepoint.p0(i64 123, i32 0, ptr elementtype(void ()) %callee, i32 0, i32 0, i32 0, i32 0)
 ret void
}
