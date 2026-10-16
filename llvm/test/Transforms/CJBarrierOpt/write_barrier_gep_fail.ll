; RUN: opt --cj-barrier-opt -S < %s | FileCheck %s

%record3 = type { i32, i8 addrspace(1)* }
%record2 = type { i32, %record3 }
%record1 = type { i32, i8 addrspace(1)*, %record2 }

%BitMap = type { i32, [0 x i8] }
%KlassInfo.0 = type { i32, i32, %BitMap*, i8*, i8**, i64*, i64*, i64*, i32, [0 x i8*] }
%KlassInfo.1 = type { i32, i32, %BitMap*, i8*, i8**, i64*, i64*, i64*, i32, [1 x i8*] }
@"Klass0.objKlass" = external global %KlassInfo.0
@"Klass1.objKlass" = external global %KlassInfo.1

declare i8 addrspace(1)* @CJ_MCC_NewPinnedObjectStub(i8*, i32)
declare void @llvm.memcpy.p1i8.p1i8.i64(i8 addrspace(1)* noalias nocapture writeonly, i8 addrspace(1)* noalias nocapture readonly, i64, i1 immarg)
declare i1 @CJ_MCC_IsInstanceOf(i8 addrspace(1)*, i8*) #1
declare void @foo()

; CHECK: call void @llvm.memcpy.p1i8.p1i8.i64(i8 addrspace(1)* align 8 %4, i8 addrspace(1)* align 8 %5, i64 8, i1 false)
; CHECK: call void @llvm.memcpy.p1i8.p1i8.i64(i8 addrspace(1)* align 8 %test0, i8 addrspace(1)* align 8 %5, i64 8, i1 false)

define void @foo1(i8 addrspace(1)* %this, %record3 addrspace(1)* %0) #0 gc "cangjie" {
entry:
  %test0 = call i8 addrspace(1)* @CJ_MCC_NewPinnedObjectStub(i8* bitcast (%KlassInfo.0* @"Klass0.objKlass" to i8*), i32 16)
  %test1 = call i1 @CJ_MCC_IsInstanceOf(i8 addrspace(1)* %this, i8* bitcast (%KlassInfo.1* @"Klass1.objKlass" to i8*))
  %1 = bitcast i8 addrspace(1)* %this to %record1 addrspace(1)*
  %2 = getelementptr inbounds %record1, %record1 addrspace(1)* %1, i32 0, i32 2
  %3 = getelementptr inbounds %record2, %record2 addrspace(1)* %2, i32 0, i32 1
  call void @foo()
  %4 = bitcast  %record3 addrspace(1)* %3 to i8 addrspace(1)*
  %5 = bitcast  %record3 addrspace(1)* %0 to i8 addrspace(1)*
  call void @llvm.memcpy.p1i8.p1i8.i64(i8 addrspace(1)* align 8 %4, i8 addrspace(1)* align 8 %5, i64 8, i1 false)
  %test2 = call i1 @CJ_MCC_IsInstanceOf(i8 addrspace(1)* %this, i8* bitcast (%KlassInfo.1* @"Klass1.objKlass" to i8*))
  call void @llvm.memcpy.p1i8.p1i8.i64(i8 addrspace(1)* align 8 %test0, i8 addrspace(1)* align 8 %5, i64 8, i1 false)
  ret void
}

attributes #0 = { "hasRcdParam" }
attributes #1 = { "cj-runtime" "gc-leaf-function" }
