; RUN: opt -enable-new-pm=false --cj-barrier-opt -S < %s | FileCheck %s

%record3 = type { i32, i8 addrspace(1)* }
%record2 = type { i32, %record3 }
%record1 = type { i32, i8 addrspace(1)*, %record2 }

%BitMap = type { i32, [0 x i8] }
%KlassInfo.0 = type { i32, i32, %BitMap*, i8*, i8**, i64*, i64*, i64*, i32, [0 x i8*] }
%KlassInfo.1 = type { i32, i32, %BitMap*, i8*, i8**, i64*, i64*, i64*, i32, [1 x i8*] }
@"Klass0.objKlass" = external global %KlassInfo.0
@"Klass1.objKlass" = external global %KlassInfo.1

declare void @llvm.memcpy.p1i8.p1i8.i64(i8 addrspace(1)* noalias nocapture writeonly, i8 addrspace(1)* noalias nocapture readonly, i64, i1 immarg)
declare i1 @CJ_MCC_IsInstanceOf(i8 addrspace(1)*, i8*) #1
declare i8* @CJ_MCC_GetExceptionWrapper() #1
declare i8 addrspace(1)* @CJ_MCC_BeginCatch(i8*) #1
declare void @CJ_MCC_EndCatch() #1
declare void @CJ_MCC_ThrowException(i8 addrspace(1)*)
declare i32 @personality_function()
declare i8 addrspace(1)* @CJ_MCC_NewPinnedObjectStub(i8*, i32)
declare i8 addrspace(1)* @CJ_MCC_NewObjectStub(i8*, i32)
declare void @foo()

define void @foo1(i8 addrspace(1)* %this, %record3 addrspace(1)* %0) #0 gc "cangjie"  personality i32 ()* @personality_function {
entry:
  %test0 = load i8, i8 addrspace(1)* %this
  %cond = icmp ne i8 %test0, 0
  br i1 %cond, label %if, label %else

if:                                        ; preds = %entry
  %test1 = invoke i8 addrspace(1)* @CJ_MCC_NewPinnedObjectStub(i8* bitcast (%KlassInfo.0* @"Klass0.objKlass" to i8*), i32 16)
        to label %invoke1 unwind label %finally

invoke1:                                        ; preds = %if
  call void @foo()
  br label %thunk

else:                                        ; preds = %entry
  %test2 = invoke i8 addrspace(1)* @CJ_MCC_NewObjectStub(i8* bitcast (%KlassInfo.0* @"Klass0.objKlass" to i8*), i32 16)
        to label %invoke2 unwind label %finally

invoke2:                                        ; preds = %else
  br label %thunk

thunk:                                        ; preds = %invoke1, %invoke2
  %test3 = phi i8 addrspace(1)* [ %test1, %invoke1 ], [ %test2, %invoke2 ]
  br label %body

; CHECK: call void @llvm.memcpy.p1i8.p1i8.i64(i8 addrspace(1)* align 8 %4, i8 addrspace(1)* align 8 %5, i64 8, i1 false)
; CHECK: call void @llvm.memcpy.p1i8.p1i8.i64(i8 addrspace(1)* align 8 %test3, i8 addrspace(1)* align 8 %5, i64 8, i1 false)

body:                                         ; preds = %thunk
  %test4 = call i1 @CJ_MCC_IsInstanceOf(i8 addrspace(1)* %this, i8* bitcast (%KlassInfo.1* @"Klass1.objKlass" to i8*))
  %1 = bitcast i8 addrspace(1)* %this to %record1 addrspace(1)*
  %2 = getelementptr inbounds %record1, %record1 addrspace(1)* %1, i32 0, i32 2
  %3 = getelementptr inbounds %record2, %record2 addrspace(1)* %2, i32 0, i32 1
  %4 = bitcast  %record3 addrspace(1)* %3 to i8 addrspace(1)*
  %5 = bitcast  %record3 addrspace(1)* %0 to i8 addrspace(1)*
  call void @llvm.memcpy.p1i8.p1i8.i64(i8 addrspace(1)* align 8 %4, i8 addrspace(1)* align 8 %5, i64 8, i1 false)
  %test5 = call i1 @CJ_MCC_IsInstanceOf(i8 addrspace(1)* %this, i8* bitcast (%KlassInfo.1* @"Klass1.objKlass" to i8*))
  call void @llvm.memcpy.p1i8.p1i8.i64(i8 addrspace(1)* align 8 %test3, i8 addrspace(1)* align 8 %5, i64 8, i1 false)
  ret void

finally:                                 ; preds = %if, %else
  %6 = landingpad token
       catch i8* bitcast (%KlassInfo.0* @"Klass0.objKlass" to i8*)
       catch i8* null
  %7 = call i8* @CJ_MCC_GetExceptionWrapper()
  %8 = call i8 addrspace(1)* @CJ_MCC_BeginCatch(i8* %7)
  call void @CJ_MCC_EndCatch()
  call void @CJ_MCC_ThrowException(i8 addrspace(1)* %8)
  unreachable
}

attributes #0 = { "hasRcdParam" }
attributes #1 = { "cj-runtime" "gc-leaf-function" }
