; RUN: opt -passes=cj-runtime-lowering,verify -S < %s | FileCheck %s

%Record = type { i8 addrspace(1)*, i64 }
%TypeInfo = type { i8*, i8, i8, i16, i32, i8*, i32, i8, i8, i32*, i8*, i8*, i8*, i8*, i8*, i8* }
@Int64.ti = external global %TypeInfo, !RelatedType !0 #0

declare i8 addrspace(1)* @llvm.cj.alloca.generic(i8*, i32)
declare void @koo(i8 addrspace(1)* noalias sret(i8), %TypeInfo*) gc "cangjie"
declare i32 @__gxx_personality_v0(...)
declare void @may_throw()

; CHECK-LABEL: define i64 @invoke_alloca_phi
; CHECK:       entry:
; CHECK:         %[[ALLOCA:.*]] = alloca { %TypeInfo*, i64 }, align 8
; CHECK:       bb_invoke:
; CHECK-NEXT:    store
; CHECK:         br label %cont
; CHECK-NOT:     invoke i8
; CHECK:       lpad:
; CHECK-NOT:     [ 1, %bb_invoke ]
; CHECK:         landingpad

define i64 @invoke_alloca_phi(i64 %x) gc "cangjie" personality i8* bitcast (i32 (...)* @__gxx_personality_v0 to i8*) {
entry:
  invoke void @may_throw() to label %bb_invoke unwind label %lpad

bb_invoke:
  %obj = invoke i8 addrspace(1)* @llvm.cj.alloca.generic(i8* bitcast (%TypeInfo* @Int64.ti to i8*), i32 8)
          to label %cont unwind label %lpad

cont:
  %bc = bitcast i8 addrspace(1)* %obj to i8* addrspace(1)*
  %ti.payload = getelementptr i8*, i8* addrspace(1)* %bc, i32 1
  %payload = bitcast i8* addrspace(1)* %ti.payload to i64 addrspace(1)*
  store i64 %x, i64 addrspace(1)* %payload, align 8
  call void @koo(i8 addrspace(1)* noalias sret(i8) %obj, %TypeInfo* @Int64.ti)
  ret i64 %x

lpad:
  %success.1 = phi i32 [ 0, %entry ], [ 1, %bb_invoke ]
  %lp = landingpad { i8*, i32 } cleanup
  ret i64 %x
}

attributes #0 = { "CFileKlass" "NotModifiableClass" }

!0 = !{!"Int64.Type"}
