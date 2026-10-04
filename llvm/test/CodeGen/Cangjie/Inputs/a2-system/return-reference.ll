define i8 addrspace(1)* @test(i8 addrspace(1)* %root)  gc "cangjie" {
ret i8 addrspace(1)* %root
}

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_p0"}
