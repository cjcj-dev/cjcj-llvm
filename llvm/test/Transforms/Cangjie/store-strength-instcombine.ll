; RUN: opt -S -passes=instcombine < %s | FileCheck %s
; Rebuilding a store to fold a value cast or sink equal stores preserves strength.
; The same merge cannot choose one arm's strength for differently decorated stores.
define void @cast(i32 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p) {
; CHECK-LABEL: define void @cast(
; CHECK: store cj_strength(2) i32 addrspace(1)* %v,
  %cast = bitcast i32 addrspace(1)* %v to i8 addrspace(1)*
  store cj_strength(2) i8 addrspace(1)* %cast, i8 addrspace(1)* addrspace(1)* %p
  ret void
}
define void @same(i1 %c, i8 addrspace(1)* %v, i8 addrspace(1)* %w, i8 addrspace(1)* addrspace(1)* %p) {
; CHECK-LABEL: define void @same(
; CHECK: end:
; CHECK: store cj_strength(2)
entry:
  br i1 %c, label %a, label %b
a:
  store cj_strength(2) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p
  br label %end
b:
  store cj_strength(2) i8 addrspace(1)* %w, i8 addrspace(1)* addrspace(1)* %p
  br label %end
end:
  ret void
}
define void @mixed(i1 %c, i8 addrspace(1)* %v, i8 addrspace(1)* %w, i8 addrspace(1)* addrspace(1)* %p) {
; CHECK-LABEL: define void @mixed(
; CHECK: a:
; CHECK: store cj_strength(2)
; CHECK: b:
; CHECK: store cj_strength(1)
entry:
  br i1 %c, label %a, label %b
a:
  store cj_strength(2) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p
  br label %end
b:
  store cj_strength(1) i8 addrspace(1)* %w, i8 addrspace(1)* addrspace(1)* %p
  br label %end
end:
  ret void
}
define void @mixed_unknown(i1 %c, i8 addrspace(1)* %v, i8 addrspace(1)* %w, i8 addrspace(1)* addrspace(1)* %p) {
; CHECK-LABEL: define void @mixed_unknown(
; CHECK: a:
; CHECK: store cj_strength(2)
; CHECK: b:
; CHECK: store i8 addrspace(1)*
entry:
  br i1 %c, label %a, label %b
a:
  store cj_strength(2) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p
  br label %end
b:
  store i8 addrspace(1)* %w, i8 addrspace(1)* addrspace(1)* %p
  br label %end
end:
  ret void
}
