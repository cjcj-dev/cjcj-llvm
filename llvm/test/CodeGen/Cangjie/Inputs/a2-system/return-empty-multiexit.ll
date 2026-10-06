define void @test(i1 %b)  gc "cangjie" {
br i1 %b, label %a, label %z
a:
ret void
z:
call void @callee()
ret void
}
declare void @callee()
declare void @other()

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_p0"}
