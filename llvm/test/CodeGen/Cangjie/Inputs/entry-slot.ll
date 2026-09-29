declare void @callee() "gc-leaf-function"

define void @slot_neighbor() gc "cangjie" {
  call void @callee()
  ret void
}

define i32 @slot_leaf() #0 gc "cangjie" {
  ret i32 7
}

; No calls and no return poll: FnInfo must be recorded independently.
define i64 @slot_gc_leaf(i64 %n) #1 gc "cangjie" {
  %buf = alloca [24 x i64], align 16
  %p = getelementptr [24 x i64], [24 x i64]* %buf, i64 0, i64 23
  store volatile i64 %n, i64* %p, align 8
  %v = load volatile i64, i64* %p, align 8
  ret i64 %v
}

define i32 @slot_plain() {
  ret i32 9
}

attributes #0 = { "leaf-function" }
attributes #1 = { "gc-leaf-function" }
!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"entryslot"}
