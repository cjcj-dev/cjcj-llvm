declare i64 @GetCJThreadIdForMutexOpt()
declare void @SetDebugLocation()
define void @test(void ()* %fp)  gc "cangjie" {
%t = call i64 @GetCJThreadIdForMutexOpt()
call void @SetDebugLocation()
ret void
}

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_p0"}
