declare void @callee()
declare void @other()
define void @test(void ()* %fp)  {
call void @callee()
call void %fp()
call void @other()
call void @callee()
ret void
}

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_p0"}
