; Parser/emission control only. Generic G is not declared a CJ compressed graph.
; This input receives no managed execution clearance.
declare void @callee()
declare void @llvm.experimental.patchpoint.void(i64, i32, i8*, i32, ...)
define void @test() gc "cangjie" {
  call void (i64, i32, i8*, i32, ...) @llvm.experimental.patchpoint.void(i64 11, i32 16, i8* bitcast (void ()* @callee to i8*), i32 0)
  call void (i64, i32, i8*, i32, ...) @llvm.experimental.patchpoint.void(i64 12, i32 16, i8* null, i32 0)
  ret void
}
!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_system"}
