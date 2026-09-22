; RUN: opt -S -passes=gvn-hoist %s | FileCheck %s
; ZGC zBarrierSetC2.cpp:342-373 / memnode.cpp:4021: distinct store
; barrier semantics must not become a single operation through value numbering.
; All ordered pairs include unknown (0), strong (1), and no-keep-alive (2).

define void @pair_0_0(i1 %c, i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p) {
; CHECK-LABEL: define void @pair_0_0(
; CHECK: store i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8{{ *$}}
; CHECK-NOT: store
; CHECK: ret void
entry:
 br i1 %c, label %a, label %b
a:
 store i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8
 br label %end
b:
 store i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8
 br label %end
end:
 ret void
}

define void @pair_0_1(i1 %c, i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p) {
; CHECK-LABEL: define void @pair_0_1(
; CHECK: br i1 %c
; CHECK: store i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8{{ *$}}
; CHECK: store cj_strength(1) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8{{ *$}}
; CHECK-NOT: store
; CHECK: ret void
entry:
 br i1 %c, label %a, label %b
a:
 store i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8
 br label %end
b:
 store cj_strength(1) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8
 br label %end
end:
 ret void
}

define void @pair_0_2(i1 %c, i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p) {
; CHECK-LABEL: define void @pair_0_2(
; CHECK: br i1 %c
; CHECK: store i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8{{ *$}}
; CHECK: store cj_strength(2) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8{{ *$}}
; CHECK-NOT: store
; CHECK: ret void
entry:
 br i1 %c, label %a, label %b
a:
 store i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8
 br label %end
b:
 store cj_strength(2) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8
 br label %end
end:
 ret void
}

define void @pair_1_0(i1 %c, i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p) {
; CHECK-LABEL: define void @pair_1_0(
; CHECK: br i1 %c
; CHECK: store cj_strength(1) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8{{ *$}}
; CHECK: store i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8{{ *$}}
; CHECK-NOT: store
; CHECK: ret void
entry:
 br i1 %c, label %a, label %b
a:
 store cj_strength(1) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8
 br label %end
b:
 store i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8
 br label %end
end:
 ret void
}

define void @pair_1_1(i1 %c, i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p) {
; CHECK-LABEL: define void @pair_1_1(
; CHECK: store cj_strength(1) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8{{ *$}}
; CHECK-NOT: store
; CHECK: ret void
entry:
 br i1 %c, label %a, label %b
a:
 store cj_strength(1) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8
 br label %end
b:
 store cj_strength(1) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8
 br label %end
end:
 ret void
}

define void @pair_1_2(i1 %c, i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p) {
; CHECK-LABEL: define void @pair_1_2(
; CHECK: br i1 %c
; CHECK: store cj_strength(1) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8{{ *$}}
; CHECK: store cj_strength(2) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8{{ *$}}
; CHECK-NOT: store
; CHECK: ret void
entry:
 br i1 %c, label %a, label %b
a:
 store cj_strength(1) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8
 br label %end
b:
 store cj_strength(2) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8
 br label %end
end:
 ret void
}

define void @pair_2_0(i1 %c, i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p) {
; CHECK-LABEL: define void @pair_2_0(
; CHECK: br i1 %c
; CHECK: store cj_strength(2) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8{{ *$}}
; CHECK: store i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8{{ *$}}
; CHECK-NOT: store
; CHECK: ret void
entry:
 br i1 %c, label %a, label %b
a:
 store cj_strength(2) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8
 br label %end
b:
 store i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8
 br label %end
end:
 ret void
}

define void @pair_2_1(i1 %c, i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p) {
; CHECK-LABEL: define void @pair_2_1(
; CHECK: br i1 %c
; CHECK: store cj_strength(2) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8{{ *$}}
; CHECK: store cj_strength(1) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8{{ *$}}
; CHECK-NOT: store
; CHECK: ret void
entry:
 br i1 %c, label %a, label %b
a:
 store cj_strength(2) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8
 br label %end
b:
 store cj_strength(1) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8
 br label %end
end:
 ret void
}

define void @pair_2_2(i1 %c, i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p) {
; CHECK-LABEL: define void @pair_2_2(
; CHECK: store cj_strength(2) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8{{ *$}}
; CHECK-NOT: store
; CHECK: ret void
entry:
 br i1 %c, label %a, label %b
a:
 store cj_strength(2) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8
 br label %end
b:
 store cj_strength(2) i8 addrspace(1)* %v, i8 addrspace(1)* addrspace(1)* %p, align 8
 br label %end
end:
 ret void
}
