; RUN: opt < %s -mtriple=x86_64-unknown-linux-gnu -passes=cj-pea -S | FileCheck %s --implicit-check-not='alloca ' --implicit-check-not='call void @w_dtor(' --implicit-check-not='invoke void @w_dtor(' --implicit-check-not='call void @throwing_dtor(' --implicit-check-not='cj.finalizer.unwind'
; RUN: opt < %s -mtriple=aarch64-unknown-linux-gnu -passes=cj-pea -S | FileCheck %s --implicit-check-not='alloca ' --implicit-check-not='call void @w_dtor(' --implicit-check-not='invoke void @w_dtor(' --implicit-check-not='call void @throwing_dtor(' --implicit-check-not='cj.finalizer.unwind'

%BitMap = type { i32, [0 x i8] }
%TypeInfo = type { i8*, i8, i8, i16, i32, %BitMap*, i32, i8, i8, i32*, i8*, i8*, i8*, %TypeInfo*, i8*, i8* }
%ObjLayout.W = type { i8* }

@g = global i8 addrspace(1)* null

@"std.core$Object.ti" = external global %TypeInfo
@"default$W.name" = internal global [12 x i8] c"default$W\00\00\00", align 1
@"default$W.ti.offsets" = internal global [1 x i32] [i32 0]
@"default$W.ti.fields" = internal global [1 x %TypeInfo*] [%TypeInfo* @"std.core$Object.ti"]
@"default$W.fieldNames" = internal global [1 x i8*] [i8* getelementptr inbounds ([3 x i8], [3 x i8]* @"default$W.field.1.name", i32 0, i32 0)]
@"default$W.field.1.name" = internal global [3 x i8] c"h\00\00"

@W.ti = weak_odr global %TypeInfo {
  i8* getelementptr inbounds ([12 x i8], [12 x i8]* @"default$W.name", i32 0, i32 0),
  i8 -128, i8 0, i16 2, i32 16, %BitMap* null, i32 0, i8 8, i8 0,
  i32* getelementptr inbounds ([1 x i32], [1 x i32]* @"default$W.ti.offsets", i32 0, i32 0),
  i8* null,
  i8* bitcast (void (i8 addrspace(1)*, %TypeInfo*)* @w_dtor to i8*),
  i8* bitcast ([1 x %TypeInfo*]* @"default$W.ti.fields" to i8*),
  %TypeInfo* @"std.core$Object.ti", i8* null,
  i8* bitcast ([1 x i8*]* @"default$W.fieldNames" to i8*)
}, !RelatedType !0

@Throw.ti = weak_odr global %TypeInfo {
  i8* getelementptr inbounds ([12 x i8], [12 x i8]* @"default$W.name", i32 0, i32 0),
  i8 -128, i8 0, i16 2, i32 16, %BitMap* null, i32 0, i8 8, i8 0,
  i32* getelementptr inbounds ([1 x i32], [1 x i32]* @"default$W.ti.offsets", i32 0, i32 0),
  i8* null,
  i8* bitcast (void (i8 addrspace(1)*, %TypeInfo*)* @throwing_dtor to i8*),
  i8* bitcast ([1 x %TypeInfo*]* @"default$W.ti.fields" to i8*),
  %TypeInfo* @"std.core$Object.ti", i8* null,
  i8* bitcast ([1 x i8*]* @"default$W.fieldNames" to i8*)
}, !RelatedType !0

declare i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8*, i32)
declare i8* @opaque_get()
declare i64 @opaque_call(i8*, i64) nounwind
declare i64 @may_throw_call(i8*, i64)
declare i64 @use_raw(i8*)
declare void @opaque_release(i8*)
declare void @CJ_MCC_ThrowException(i8 addrspace(1)*)
declare void @may_throw()
declare i32 @__cj_personality_v0(...)
declare void @llvm.memset.p1i8.i64(i8 addrspace(1)* nocapture writeonly, i8, i64, i1 immarg)
define i64 @use_obj(i8 addrspace(1)* nocapture %p) nounwind readnone {
  ret i64 0
}
define i8 addrspace(1)* @id(i8 addrspace(1)* nocapture %p) nounwind readnone {
  ret i8 addrspace(1)* %p
}
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)

define void @store_self(i8 addrspace(1)* nocapture %p) nounwind {
  %f = getelementptr inbounds i8, i8 addrspace(1)* %p, i64 8
  %hslot = bitcast i8 addrspace(1)* %f to i8* addrspace(1)*
  %as = addrspacecast i8 addrspace(1)* %p to i8*
  store i8* %as, i8* addrspace(1)* %hslot, align 8
  ret void
}

declare i64 @foreign_blackhole(i8*) nounwind

define i64 @method_readonly(i8 addrspace(1)* %this, i64 %i) nounwind readonly {
  %p = getelementptr inbounds i8, i8 addrspace(1)* %this, i64 8
  %hslot = bitcast i8 addrspace(1)* %p to i8* addrspace(1)*
  %h = load i8*, i8* addrspace(1)* %hslot, align 8
  %r = ptrtoint i8* %h to i64
  %x = add i64 %r, %i
  ret i64 %x
}

define i64 @method_maywrite(i8 addrspace(1)* %this, i64 %i) nounwind {
  %p = getelementptr inbounds i8, i8 addrspace(1)* %this, i64 8
  %hslot = bitcast i8 addrspace(1)* %p to i8* addrspace(1)*
  %h = load i8*, i8* addrspace(1)* %hslot, align 8
  %r = call i64 @foreign_blackhole(i8* %h)
  %x = add i64 %r, %i
  ret i64 %x
}

define void @w_dtor(i8 addrspace(1)* %this, %TypeInfo* %ti) nounwind gc "cangjie" {
  %p = getelementptr inbounds i8, i8 addrspace(1)* %this, i64 8
  %hslot = bitcast i8 addrspace(1)* %p to i8* addrspace(1)*
  %h = load i8*, i8* addrspace(1)* %hslot, align 8
  call void @opaque_release(i8* %h)
  ret void
}

define void @throwing_dtor(i8 addrspace(1)* %this, %TypeInfo* %ti) gc "cangjie" {
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %this)
  unreachable
}


; CHECK-LABEL: @loop_body_alloc(
; CHECK: call {{.*}}@CJ_MCC_NewFinalizer(
; CHECK: }
define i64 @loop_body_alloc() gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
entry:
  br label %header

header:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %sum = phi i64 [ 0, %entry ], [ %add, %latch ]
  %cmp = icmp slt i64 %i, 10
  br i1 %cmp, label %body, label %exit

body:
  %handle = call i8* @opaque_get()
  %obj = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* bitcast (%TypeInfo* @W.ti to i8*), i32 16)
  call void @llvm.memset.p1i8.i64(i8 addrspace(1)* %obj, i8 0, i64 16, i1 false)
  %p = getelementptr inbounds i8, i8 addrspace(1)* %obj, i64 8
  %hslot = bitcast i8 addrspace(1)* %p to i8* addrspace(1)*
  store i8* %handle, i8* addrspace(1)* %hslot, align 8
  %h = load i8*, i8* addrspace(1)* %hslot, align 8
  %v = call i64 @opaque_call(i8* %h, i64 0)
  br label %latch

latch:
  %add = add i64 %sum, %v
  %next = add i64 %i, 1
  br label %header

exit:
  ret i64 %sum
}

; CHECK-LABEL: @loop_then_invoke(
; CHECK: call {{.*}}@CJ_MCC_NewFinalizer(
; CHECK: invoke {{.*}}@may_throw(
; CHECK: }
define i64 @loop_then_invoke() gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
entry:
  br label %header

header:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %sum = phi i64 [ 0, %entry ], [ %add, %latch ]
  %cmp = icmp slt i64 %i, 10
  br i1 %cmp, label %body, label %exit

body:
  %handle = call i8* @opaque_get()
  %obj = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* bitcast (%TypeInfo* @W.ti to i8*), i32 16)
  %p = getelementptr inbounds i8, i8 addrspace(1)* %obj, i64 8
  %hslot = bitcast i8 addrspace(1)* %p to i8* addrspace(1)*
  store i8* %handle, i8* addrspace(1)* %hslot, align 8
  %h = load i8*, i8* addrspace(1)* %hslot, align 8
  %v = call i64 @opaque_call(i8* %h, i64 0)
  br label %latch

latch:
  %add = add i64 %sum, %v
  %next = add i64 %i, 1
  br label %header

exit:
  invoke void @may_throw() to label %ret unwind label %lpad

ret:
  ret i64 %sum

lpad:
  %lp = landingpad { i8*, i32 } cleanup
  resume { i8*, i32 } %lp
}

; CHECK-LABEL: @loop_latch_alloc(
; CHECK: call {{.*}}@CJ_MCC_NewFinalizer(
; CHECK: }
define i64 @loop_latch_alloc() gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
entry:
  br label %header

header:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %sum = phi i64 [ 0, %entry ], [ %add, %latch ]
  %cmp = icmp slt i64 %i, 10
  br i1 %cmp, label %latch, label %exit

latch:
  %handle = call i8* @opaque_get()
  %obj = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* bitcast (%TypeInfo* @W.ti to i8*), i32 16)
  %p = getelementptr inbounds i8, i8 addrspace(1)* %obj, i64 8
  %hslot = bitcast i8 addrspace(1)* %p to i8* addrspace(1)*
  store i8* %handle, i8* addrspace(1)* %hslot, align 8
  %h = load i8*, i8* addrspace(1)* %hslot, align 8
  %v = call i64 @opaque_call(i8* %h, i64 0)
  %add = add i64 %sum, %v
  %next = add i64 %i, 1
  br label %header

exit:
  ret i64 %sum
}

; CHECK-LABEL: @loop_phi(
; CHECK: call {{.*}}@CJ_MCC_NewFinalizer(
; CHECK: }
define i64 @loop_phi() gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
entry:
  br label %header

header:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %saved = phi i8 addrspace(1)* [ null, %entry ], [ %obj, %latch ]
  %cmp = icmp slt i64 %i, 10
  br i1 %cmp, label %body, label %exit

body:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* bitcast (%TypeInfo* @W.ti to i8*), i32 16)
  %p = getelementptr inbounds i8, i8 addrspace(1)* %obj, i64 8
  %slot = bitcast i8 addrspace(1)* %p to i64 addrspace(1)*
  store i64 1, i64 addrspace(1)* %slot, align 8
  br label %latch

latch:
  %next = add i64 %i, 1
  br label %header

exit:
  ret i64 %i
}

; CHECK-LABEL: @loop_store_escape(
; CHECK: call {{.*}}@CJ_MCC_NewFinalizer(
; CHECK: }
define i64 @loop_store_escape() gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
entry:
  br label %header

header:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %cmp = icmp slt i64 %i, 10
  br i1 %cmp, label %body, label %exit

body:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* bitcast (%TypeInfo* @W.ti to i8*), i32 16)
  store i8 addrspace(1)* %obj, i8 addrspace(1)** @g
  br label %latch

latch:
  %next = add i64 %i, 1
  br label %header

exit:
  ret i64 %i
}

; CHECK-LABEL: @loop_body_unreachable(
; CHECK: call {{.*}}@CJ_MCC_NewFinalizer(
; CHECK: }
define i64 @loop_body_unreachable() gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
entry:
  br label %header

header:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %cmp = icmp slt i64 %i, 10
  br i1 %cmp, label %body, label %exit

body:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* bitcast (%TypeInfo* @W.ti to i8*), i32 16)
  %p = getelementptr inbounds i8, i8 addrspace(1)* %obj, i64 8
  %slot = bitcast i8 addrspace(1)* %p to i64 addrspace(1)*
  store i64 1, i64 addrspace(1)* %slot, align 8
  %ov = icmp eq i64 %i, 3
  br i1 %ov, label %trap, label %latch

trap:
  unreachable

latch:
  %next = add i64 %i, 1
  br label %header

exit:
  ret i64 %i
}

; CHECK-LABEL: @loop_throwing_dtor(
; CHECK: call {{.*}}@CJ_MCC_NewFinalizer(
; CHECK: }
define i64 @loop_throwing_dtor() gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
entry:
  br label %header

header:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %cmp = icmp slt i64 %i, 10
  br i1 %cmp, label %body, label %exit

body:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* bitcast (%TypeInfo* @Throw.ti to i8*), i32 16)
  %p = getelementptr inbounds i8, i8 addrspace(1)* %obj, i64 8
  %slot = bitcast i8 addrspace(1)* %p to i64 addrspace(1)*
  store i64 1, i64 addrspace(1)* %slot, align 8
  br label %latch

latch:
  %next = add i64 %i, 1
  br label %header

exit:
  ret i64 %i
}

; CHECK-LABEL: @loop_body_break(
; CHECK: call {{.*}}@CJ_MCC_NewFinalizer(
; CHECK: }
define i64 @loop_body_break() gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
entry:
  br label %header

header:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %cmp = icmp slt i64 %i, 10
  br i1 %cmp, label %body, label %exit

body:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* bitcast (%TypeInfo* @W.ti to i8*), i32 16)
  %p = getelementptr inbounds i8, i8 addrspace(1)* %obj, i64 8
  %slot = bitcast i8 addrspace(1)* %p to i64 addrspace(1)*
  store i64 1, i64 addrspace(1)* %slot, align 8
  %c = icmp eq i64 %i, 3
  br i1 %c, label %exit, label %latch

latch:
  %next = add i64 %i, 1
  br label %header

exit:
  ret i64 %i
}

; CHECK-LABEL: @loop_invoke_unwind_skip(
; CHECK: call {{.*}}@CJ_MCC_NewFinalizer(
; CHECK: invoke {{.*}}@may_throw(
; CHECK: }
define i64 @loop_invoke_unwind_skip() gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
entry:
  br label %header

header:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %cmp = icmp slt i64 %i, 10
  br i1 %cmp, label %body, label %exit

body:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* bitcast (%TypeInfo* @W.ti to i8*), i32 16)
  %p = getelementptr inbounds i8, i8 addrspace(1)* %obj, i64 8
  %slot = bitcast i8 addrspace(1)* %p to i64 addrspace(1)*
  store i64 1, i64 addrspace(1)* %slot, align 8
  invoke void @may_throw() to label %latch unwind label %lpad

latch:
  %next = add i64 %i, 1
  br label %header

lpad:
  %lp = landingpad { i8*, i32 } cleanup
  resume { i8*, i32 } %lp

exit:
  ret i64 %i
}

; CHECK-LABEL: @loop_nested_inner(
; CHECK: call {{.*}}@CJ_MCC_NewFinalizer(
; CHECK: }
define i64 @loop_nested_inner() gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
entry:
  br label %header

header:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %sum = phi i64 [ 0, %entry ], [ %add, %latch ]
  %cmp = icmp slt i64 %i, 10
  br i1 %cmp, label %body, label %exit

body:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* bitcast (%TypeInfo* @W.ti to i8*), i32 16)
  %p = getelementptr inbounds i8, i8 addrspace(1)* %obj, i64 8
  %slot = bitcast i8 addrspace(1)* %p to i64 addrspace(1)*
  store i64 1, i64 addrspace(1)* %slot, align 8
  br label %iheader

iheader:
  %j = phi i64 [ 0, %body ], [ %jnext, %ilatch ]
  %vsum = phi i64 [ 0, %body ], [ %vadd, %ilatch ]
  %jcmp = icmp slt i64 %j, 4
  br i1 %jcmp, label %ibody, label %latch

ibody:
  %v = load i64, i64 addrspace(1)* %slot, align 8
  %vadd = add i64 %vsum, %v
  br label %ilatch

ilatch:
  %jnext = add i64 %j, 1
  br label %iheader

latch:
  %add = add i64 %sum, %vsum
  %next = add i64 %i, 1
  br label %header

exit:
  ret i64 %sum
}

; CHECK-LABEL: @loop_maythrow_call(
; CHECK: call {{.*}}@CJ_MCC_NewFinalizer(
; CHECK: call {{.*}}@may_throw_call(
; CHECK: }
define i64 @loop_maythrow_call() gc "cangjie" {
entry:
  br label %header

header:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %sum = phi i64 [ 0, %entry ], [ %add, %latch ]
  %cmp = icmp slt i64 %i, 10
  br i1 %cmp, label %latch, label %exit

latch:
  %handle = call i8* @opaque_get()
  ; 16 = 8-byte object head + 8-byte payload (ObjLayout {i64}).
  %obj = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* bitcast (%TypeInfo* @W.ti to i8*), i32 16)
  %p = getelementptr inbounds i8, i8 addrspace(1)* %obj, i64 8
  %hslot = bitcast i8 addrspace(1)* %p to i8* addrspace(1)*
  store i8* %handle, i8* addrspace(1)* %hslot, align 8
  %h = load i8*, i8* addrspace(1)* %hslot, align 8
  %v = call i64 @may_throw_call(i8* %h, i64 0)
  %add = add i64 %sum, %v
  %next = add i64 %i, 1
  br label %header

exit:
  ret i64 %sum
}

; CHECK-LABEL: @loop_gcread_ref(
; CHECK: call {{.*}}@CJ_MCC_NewFinalizer(
; CHECK: }
define i64 @loop_gcread_ref() gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
entry:
  br label %header

header:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %cmp = icmp slt i64 %i, 10
  br i1 %cmp, label %body, label %exit

body:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* bitcast (%TypeInfo* @W.ti to i8*), i32 16)
  %p = getelementptr inbounds i8, i8 addrspace(1)* %obj, i64 8
  %slot = bitcast i8 addrspace(1)* %p to i8 addrspace(1)* addrspace(1)*
  %f = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* %obj, i8 addrspace(1)* addrspace(1)* %slot)
  %v = call i64 @use_obj(i8 addrspace(1)* %f)
  br label %latch

latch:
  %next = add i64 %i, 1
  br label %header

exit:
  ret i64 %i
}

; CHECK-LABEL: @loop_gcwrite_ref(
; CHECK: call {{.*}}@CJ_MCC_NewFinalizer(
; CHECK: }
define i64 @loop_gcwrite_ref() gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
entry:
  br label %header

header:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %cmp = icmp slt i64 %i, 10
  br i1 %cmp, label %body, label %exit

body:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* bitcast (%TypeInfo* @W.ti to i8*), i32 16)
  %p = getelementptr inbounds i8, i8 addrspace(1)* %obj, i64 8
  %slot = bitcast i8 addrspace(1)* %p to i8 addrspace(1)* addrspace(1)*
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* null, i8 addrspace(1)* %obj, i8 addrspace(1)* addrspace(1)* %slot)
  br label %latch

latch:
  %next = add i64 %i, 1
  br label %header

exit:
  ret i64 %i
}

; CHECK-LABEL: @loop_call_use_obj(
; CHECK: call {{.*}}@CJ_MCC_NewFinalizer(
; CHECK: }
define i64 @loop_call_use_obj() gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
entry:
  br label %header

header:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %cmp = icmp slt i64 %i, 10
  br i1 %cmp, label %body, label %exit

body:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* bitcast (%TypeInfo* @W.ti to i8*), i32 16)
  call void @llvm.memset.p1i8.i64(i8 addrspace(1)* %obj, i8 0, i64 16, i1 false)
  %v = call i64 @use_obj(i8 addrspace(1)* %obj)
  br label %latch

latch:
  %next = add i64 %i, 1
  br label %header

exit:
  ret i64 %i
}

; CHECK-LABEL: @loop_maythrow_call_personality(
; CHECK: call {{.*}}@CJ_MCC_NewFinalizer(
; CHECK: call {{.*}}@may_throw_call(
; CHECK: }
define i64 @loop_maythrow_call_personality() gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
entry:
  br label %header

header:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %sum = phi i64 [ 0, %entry ], [ %add, %latch ]
  %cmp = icmp slt i64 %i, 10
  br i1 %cmp, label %latch, label %exit

latch:
  %handle = call i8* @opaque_get()
  ; 16 = 8-byte object head + 8-byte payload (ObjLayout {i64}).
  %obj = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* bitcast (%TypeInfo* @W.ti to i8*), i32 16)
  %p = getelementptr inbounds i8, i8 addrspace(1)* %obj, i64 8
  %hslot = bitcast i8 addrspace(1)* %p to i8* addrspace(1)*
  store i8* %handle, i8* addrspace(1)* %hslot, align 8
  %h = load i8*, i8* addrspace(1)* %hslot, align 8
  %v = call i64 @may_throw_call(i8* %h, i64 0)
  %add = add i64 %sum, %v
  %next = add i64 %i, 1
  br label %header

exit:
  ret i64 %sum
}

; CHECK-LABEL: @loop_call_ret_alias(
; CHECK: call {{.*}}@CJ_MCC_NewFinalizer(
; CHECK: }
define i64 @loop_call_ret_alias() gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
entry:
  br label %header

header:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %saved = phi i8 addrspace(1)* [ null, %entry ], [ %p, %latch ]
  %cmp = icmp slt i64 %i, 10
  br i1 %cmp, label %body, label %exit

body:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* bitcast (%TypeInfo* @W.ti to i8*), i32 16)
  %p = call i8 addrspace(1)* @id(i8 addrspace(1)* %obj)
  br label %latch

latch:
  %next = add i64 %i, 1
  br label %header

exit:
  %r = call i64 @use_obj(i8 addrspace(1)* %saved)
  ret i64 %r
}

; CHECK-LABEL: @loop_cond_alloc(
; CHECK: call {{.*}}@CJ_MCC_NewFinalizer(
; CHECK: }
define i64 @loop_cond_alloc() gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
entry:
  br label %header

header:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %acc = phi i64 [ 0, %entry ], [ %add, %latch ]
  %cmp = icmp slt i64 %i, 10
  br i1 %cmp, label %body, label %exit

body:
  %c = icmp eq i64 %i, 3
  br i1 %c, label %then, label %latch

then:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* bitcast (%TypeInfo* @W.ti to i8*), i32 16)
  %v = call i64 @use_obj(i8 addrspace(1)* %obj)
  br label %latch

latch:
  %add = phi i64 [ %acc, %body ], [ %v, %then ]
  %next = add i64 %i, 1
  br label %header

exit:
  ret i64 %acc
}

; CHECK-LABEL: @loop_diamond_uses(
; CHECK: call {{.*}}@CJ_MCC_NewFinalizer(
; CHECK: }
define i64 @loop_diamond_uses() gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
entry:
  br label %header

header:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %acc = phi i64 [ 0, %entry ], [ %add, %latch ]
  %cmp = icmp slt i64 %i, 10
  br i1 %cmp, label %body, label %exit

body:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* bitcast (%TypeInfo* @W.ti to i8*), i32 16)
  %c = icmp eq i64 %i, 3
  br i1 %c, label %then, label %else

then:
  %v1 = call i64 @use_obj(i8 addrspace(1)* %obj)
  br label %latch

else:
  %v2 = call i64 @use_obj(i8 addrspace(1)* %obj)
  br label %latch

latch:
  %v = phi i64 [ %v1, %then ], [ %v2, %else ]
  %add = add i64 %acc, %v
  %next = add i64 %i, 1
  br label %header

exit:
  ret i64 %acc
}

; CHECK-LABEL: @loop_store_self_alias(
; CHECK: call {{.*}}@CJ_MCC_NewFinalizer(
; CHECK: }
define i64 @loop_store_self_alias() gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
entry:
  br label %header

header:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %saved = phi i8* [ null, %entry ], [ %h, %latch ]
  %cmp = icmp slt i64 %i, 10
  br i1 %cmp, label %body, label %exit

body:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* bitcast (%TypeInfo* @W.ti to i8*), i32 16)
  %p = getelementptr inbounds i8, i8 addrspace(1)* %obj, i64 8
  %hslot = bitcast i8 addrspace(1)* %p to i8* addrspace(1)*
  %as0 = addrspacecast i8 addrspace(1)* %obj to i8*
  store i8* %as0, i8* addrspace(1)* %hslot, align 8
  %h = load i8*, i8* addrspace(1)* %hslot, align 8
  br label %latch

latch:
  %next = add i64 %i, 1
  br label %header

exit:
  %r = call i64 @use_raw(i8* %saved)
  ret i64 %r
}

; CHECK-LABEL: @loop_call_ret_store_alias(
; CHECK: call {{.*}}@CJ_MCC_NewFinalizer(
; CHECK: }
define i64 @loop_call_ret_store_alias() gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
entry:
  br label %header

header:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %saved = phi i8* [ null, %entry ], [ %h, %latch ]
  %cmp = icmp slt i64 %i, 10
  br i1 %cmp, label %body, label %exit

body:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* bitcast (%TypeInfo* @W.ti to i8*), i32 16)
  %p1 = call i8 addrspace(1)* @id(i8 addrspace(1)* %obj)
  %f = getelementptr inbounds i8, i8 addrspace(1)* %obj, i64 8
  %hslot = bitcast i8 addrspace(1)* %f to i8* addrspace(1)*
  %as = addrspacecast i8 addrspace(1)* %p1 to i8*
  store i8* %as, i8* addrspace(1)* %hslot, align 8
  %h = load i8*, i8* addrspace(1)* %hslot, align 8
  br label %latch

latch:
  %next = add i64 %i, 1
  br label %header

exit:
  %r = call i64 @use_raw(i8* %saved)
  ret i64 %r
}

; CHECK-LABEL: @loop_call_callee_plants_alias(
; CHECK: call {{.*}}@CJ_MCC_NewFinalizer(
; CHECK: }
define i64 @loop_call_callee_plants_alias() gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
entry:
  br label %header

header:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %saved = phi i8* [ null, %entry ], [ %h, %latch ]
  %cmp = icmp slt i64 %i, 10
  br i1 %cmp, label %body, label %exit

body:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* bitcast (%TypeInfo* @W.ti to i8*), i32 16)
  call void @store_self(i8 addrspace(1)* %obj)
  %f = getelementptr inbounds i8, i8 addrspace(1)* %obj, i64 8
  %hslot = bitcast i8 addrspace(1)* %f to i8* addrspace(1)*
  %h = load i8*, i8* addrspace(1)* %hslot, align 8
  br label %latch

latch:
  %next = add i64 %i, 1
  br label %header

exit:
  %r = call i64 @use_raw(i8* %saved)
  ret i64 %r
}

; CHECK-LABEL: @loop_call_method_readonly(
; CHECK: call {{.*}}@CJ_MCC_NewFinalizer(
; CHECK: }
define i64 @loop_call_method_readonly() gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
entry:
  br label %header

header:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %acc = phi i64 [ 0, %entry ], [ %acc2, %latch ]
  %cmp = icmp slt i64 %i, 10
  br i1 %cmp, label %body, label %exit

body:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* bitcast (%TypeInfo* @W.ti to i8*), i32 16)
  %hp = getelementptr inbounds i8, i8 addrspace(1)* %obj, i64 8
  %hslot = bitcast i8 addrspace(1)* %hp to i8* addrspace(1)*
  %h = call i8* @opaque_get()
  store i8* %h, i8* addrspace(1)* %hslot, align 8
  %v = call i64 @method_readonly(i8 addrspace(1)* %obj, i64 %i)
  %acc2 = add i64 %acc, %v
  br label %latch

latch:
  %next = add i64 %i, 1
  br label %header

exit:
  ret i64 %acc
}

; CHECK-LABEL: @loop_call_method_maywrite(
; CHECK: call {{.*}}@CJ_MCC_NewFinalizer(
; CHECK: }
define i64 @loop_call_method_maywrite() gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
entry:
  br label %header

header:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %acc = phi i64 [ 0, %entry ], [ %acc2, %latch ]
  %cmp = icmp slt i64 %i, 10
  br i1 %cmp, label %body, label %exit

body:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* bitcast (%TypeInfo* @W.ti to i8*), i32 16)
  %hp = getelementptr inbounds i8, i8 addrspace(1)* %obj, i64 8
  %hslot = bitcast i8 addrspace(1)* %hp to i8* addrspace(1)*
  %h = call i8* @opaque_get()
  store i8* %h, i8* addrspace(1)* %hslot, align 8
  %v = call i64 @method_maywrite(i8 addrspace(1)* %obj, i64 %i)
  %acc2 = add i64 %acc, %v
  br label %latch

latch:
  %next = add i64 %i, 1
  br label %header

exit:
  ret i64 %acc
}

; CHECK-LABEL: @loop_gcwrite_ref_value(
; CHECK: call {{.*}}@CJ_MCC_NewFinalizer(
; CHECK: }
define i64 @loop_gcwrite_ref_value() gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
entry:
  br label %header

header:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %cmp = icmp slt i64 %i, 10
  br i1 %cmp, label %body, label %exit

body:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* bitcast (%TypeInfo* @W.ti to i8*), i32 16)
  %p = getelementptr inbounds i8, i8 addrspace(1)* %obj, i64 8
  %slot = bitcast i8 addrspace(1)* %p to i8 addrspace(1)* addrspace(1)*
  call void @llvm.cj.gcwrite.ref(i8 addrspace(1)* %obj, i8 addrspace(1)* null, i8 addrspace(1)* addrspace(1)* %slot)
  br label %latch

latch:
  %next = add i64 %i, 1
  br label %header

exit:
  ret i64 %i
}

declare void @llvm.prefetch.p0i8(i8* nocapture readonly, i32 immarg, i32 immarg, i32 immarg)

; CHECK-LABEL: @loop_unmodeled_intrinsic(
; CHECK: call {{.*}}@CJ_MCC_NewFinalizer(
; CHECK: }
define i64 @loop_unmodeled_intrinsic() gc "cangjie" personality i32 (...)* @__cj_personality_v0 {
entry:
  br label %header

header:
  %i = phi i64 [ 0, %entry ], [ %next, %latch ]
  %cmp = icmp slt i64 %i, 10
  br i1 %cmp, label %body, label %exit

body:
  %obj = call i8 addrspace(1)* @CJ_MCC_NewFinalizer(i8* bitcast (%TypeInfo* @W.ti to i8*), i32 16)
  %as0 = addrspacecast i8 addrspace(1)* %obj to i8*
  call void @llvm.prefetch.p0i8(i8* %as0, i32 0, i32 3, i32 1)
  br label %latch

latch:
  %next = add i64 %i, 1
  br label %header

exit:
  ret i64 %i
}

!0 = !{!"ObjLayout.W"}
