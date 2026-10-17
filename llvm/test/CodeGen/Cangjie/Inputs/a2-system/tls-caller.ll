; PIC general-dynamic TLS witness. Decode actual helper/TLSDESC calls rather
; than treating a TLS source operation as a call-count oracle.
@tls = external thread_local global i64
define i64 @test() gc "cangjie" {
  %v = load volatile i64, i64* @tls
  ret i64 %v
}
!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_system"}
