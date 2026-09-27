; Actual llc input for the native MachO link check. Different function sections
; and input order deliberately prevent assuming file order is address order.
define void @map_first() gc "cangjie" { ret void }
define void @map_unused() gc "cangjie" { ret void }
define void @map_init() #0 gc "cangjie" { ret void }
define void @map_leaf() #1 gc "cangjie" { ret void }
define void @map_plain() { ret void }
attributes #0 = { "cjinit" }
attributes #1 = { "leaf-function" }
!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"funcmap_one"}
