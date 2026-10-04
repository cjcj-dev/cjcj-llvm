; X86-only event sled encoding. It stays dormant until the external XRay
; patcher enables it; this is not managed execution proof.
declare void @llvm.xray.customevent(i8*, i32)
declare void @llvm.xray.typedevent(i16, i8*, i32)
define void @test(i64 %ignored, i8* %data, i32 %size, i16 %type) noinline optnone gc "cangjie" {
  call void @llvm.xray.customevent(i8* %data, i32 %size)
  call void @llvm.xray.typedevent(i16 %type, i8* %data, i32 %size)
  ret void
}
!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_system"}
