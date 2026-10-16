; RUN: opt --cj-barrier-opt -S < %s | FileCheck %s
; RUN: opt -passes=cj-barrier-opt -S < %s | FileCheck %s

%record0 = type { i32, i8 addrspace(1)*, i8 addrspace(1)* }
@global0 = internal global %record0 zeroinitializer
@global1 = internal global i8 addrspace(1)* null
@global2 = internal global i8 addrspace(1)* null

%BitMap = type { i32, [0 x i8] }
%KlassInfo.0 = type { i32, i32, %BitMap*, i8*, i8**, i64*, i64*, i64*, i32, [0 x i8*] }
%record1 = type { %record2, i32 }
%record2 = type { %ObjLayout.Object }
%ObjLayout.Object = type { %KlassInfo.0* }
@"Klass0.objKlass" = external global %KlassInfo.0

declare void @llvm.cj.gcwrite.static(i8 addrspace(1)*, i8 addrspace(1)** nocapture)
declare i8 addrspace(1)* @CJ_MCC_NewPinnedObjectStub(i8*, i32)
declare void @foo()

define void @foo1() #0 gc "cangjie" {
entry:
  %test = alloca i8 addrspace(1)*
  %0 = alloca i8 addrspace(1)*
  br label %thunk

; CHECK: store i32 10, i32* getelementptr inbounds (%record0, %record0* @global0, i32 0, i32 0)
; CHECK: call void @llvm.cj.gcwrite.static(i8 addrspace(1)* %3, i8 addrspace(1)** getelementptr inbounds (%record0, %record0* @global0, i32 0, i32 1))
; CHECK: call void @llvm.cj.gcwrite.static(i8 addrspace(1)* %4, i8 addrspace(1)** getelementptr inbounds (%record0, %record0* @global0, i32 0, i32 2))
thunk:                                        ; preds = %entry
  call void @foo()
  %1 = call i8 addrspace(1)* @CJ_MCC_NewPinnedObjectStub(i8* bitcast (%KlassInfo.0* @"Klass0.objKlass" to i8*), i32 16)
  store i8 addrspace(1)* %1, i8 addrspace(1)** %0
  %2 = load i8 addrspace(1)*, i8 addrspace(1)** %0
  store i8 addrspace(1)* %2, i8 addrspace(1)** %test
  store i32 10, i32* getelementptr inbounds (%record0, %record0* @global0, i32 0, i32 0)
  %3 = load i8 addrspace(1)*, i8 addrspace(1)** @global1
  call void @llvm.cj.gcwrite.static(i8 addrspace(1)* %3, i8 addrspace(1)** getelementptr inbounds (%record0, %record0* @global0, i32 0, i32 1))
  %4 = load i8 addrspace(1)*, i8 addrspace(1)** @global2
  call void @llvm.cj.gcwrite.static(i8 addrspace(1)* %4, i8 addrspace(1)** getelementptr inbounds (%record0, %record0* @global0, i32 0, i32 2))
  br label %tmpLabel

; CHECK: store atomic i32 0, i32 addrspace(1)* %7 seq_cst
tmpLabel:                                     ; preds = %thunk
  %5 = load i8 addrspace(1)*, i8 addrspace(1)** %test
  %6 = bitcast i8 addrspace(1)* %5 to %record1 addrspace(1)*
  %7 = getelementptr inbounds %record1, %record1 addrspace(1)* %6, i32 0, i32 1
  store atomic i32 0, i32 addrspace(1)* %7 seq_cst, align 32
  br label %end

end:                                     ; preds = %tmpLabel
  ret void
}

attributes #0 = { "hasRcdParam" }