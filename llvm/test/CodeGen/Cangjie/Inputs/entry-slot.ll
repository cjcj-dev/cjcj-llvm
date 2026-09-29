declare void @callee() "gc-leaf-function"

define void @slot_neighbor() gc "cangjie" {
  call void @callee()
  ret void
}

define i32 @slot_leaf() #0 gc "cangjie" {
  ret i32 7
}

define i32 @slot_plain() {
  ret i32 9
}

attributes #0 = { "leaf-function" }
!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"entryslot"}
