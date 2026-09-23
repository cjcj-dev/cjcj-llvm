from pathlib import Path
root=Path('llvm/test/CodeGen/X86/CangjieGC')
header='''; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O0 -verify-machineinstrs -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc --cangjie-pipeline -mtriple=x86_64 -O2 -verify-machineinstrs -print-after=cj-barrier-lowering -o /dev/null < %s 2>&1 | FileCheck %s
;
; Storage domain must be proved from the final slot, after escape analysis.
target datalayout = "e-m:e-p:64:64-p1:64:64-i64:64-n8:16:32:64-S128"
'''
decl='''
declare i8 addrspace(1)* @CJ_MCC_NewObject(i8*, i32)
declare i8 addrspace(1)* @CJ_MCC_NewArray(i8*, i64, i64)
declare i8 addrspace(1)* @unknown_allocator(i8*, i32)
declare void @safepoint()
declare i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token, i32 immarg, i32 immarg)
declare token @llvm.cj.gc.statepoint(...)
declare i8 addrspace(1)* @llvm.cj.gc.result(token)
declare void @llvm.cj.gcwrite.ref(i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...)
declare i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*)
'''
alloc='''  %token = call token (...) @llvm.cj.gc.statepoint(i64 0, i32 0, i8 addrspace(1)* (i8*, i32)* @CJ_MCC_NewObject, i32 2, i32 0, i8* %type, i32 64)
  %heap = call i8 addrspace(1)* @llvm.cj.gc.result(token %token)
'''
stack='''  %storage = alloca [64 x i8], align 8
  %bytes = bitcast [64 x i8]* %storage to i8*
  %stack = addrspacecast i8* %bytes to i8 addrspace(1)*
'''
for kind in ['allocation','array','heap-phi','heap-select','mixed-phi','mixed-select','unknown','unknown-result','unbounded-gep','stack','owner-only','relocated','relocated-unknown','cycle','as0-roundtrip']:
 for mode in ['write','read']:
  proven=kind in ['allocation','array','heap-phi','heap-select','relocated']
  checks='; CHECK-LABEL: define '+('void' if mode=='write' else 'i8 addrspace(1)*')+' @probe(\n'
  if proven:
   checks+='; CHECK-NOT: g_cjHeapRangeCount\n'
  else:
   checks+='; CHECK: load i64, i64* @g_cjHeapRangeCount\n'
  checks+='; CHECK: '+('cj.storebadmask' if mode=='write' else 'cj.loadbadmask')+'\n'
  if proven: checks+='; CHECK-NOT: g_cjHeapRangeCount\n'
  checks+='; CHECK: ret '+('void' if mode=='write' else 'i8 addrspace(1)*')+'\n'
  body='entry:\n'
  if kind not in ['unknown','stack']: body+=alloc
  if kind=='array': body=body.replace('i8 addrspace(1)* (i8*, i32)* @CJ_MCC_NewObject, i32 2, i32 0, i8* %type, i32 64','i8 addrspace(1)* (i8*, i64, i64)* @CJ_MCC_NewArray, i32 3, i32 0, i8* %type, i64 8, i64 64')
  if kind=='unknown-result': body=body.replace('@CJ_MCC_NewObject','@unknown_allocator')
  if kind in ['mixed-phi','mixed-select','stack']: body+=stack
  origin='%heap'
  if kind=='unknown' or kind=='owner-only': origin='%arg'
  if kind=='stack': origin='%stack'
  if kind in ['mixed-phi','heap-phi']:
   other='%stack' if kind=='mixed-phi' else '%heap2'
   if kind=='heap-phi': body+=alloc.replace('%token','%token2').replace('%heap','%heap2')
   body+='  br i1 %cond, label %left, label %right\nleft:\n  br label %join\nright:\n  br label %join\njoin:\n  %merged = phi i8 addrspace(1)* [ %heap, %left ], [ '+other+', %right ]\n'
   origin='%merged'
  if kind=='heap-select':
   body+=alloc.replace('%token','%token2').replace('%heap','%heap2')
  if kind in ['mixed-select','heap-select']:
   body+='  %merged = select i1 %cond, i8 addrspace(1)* %heap, i8 addrspace(1)* %stack\n'
   origin='%merged'
   if kind=='heap-select': body=body.replace('i8 addrspace(1)* %stack','i8 addrspace(1)* %heap2')
  if kind in ['relocated','relocated-unknown']:
   derived='%heap' if kind=='relocated' else '%arg'
   body+='  %safepoint = call token (...) @llvm.cj.gc.statepoint(i64 1, i32 0, void ()* @safepoint, i32 0, i32 0) [ "gc-live"(i8 addrspace(1)* %heap, i8 addrspace(1)* '+derived+') ]\n  %relocated = call i8 addrspace(1)* @llvm.cj.gc.relocate.p1i8(token %safepoint, i32 0, i32 1)\n'
   origin='%relocated'
  if kind=='cycle':
   body+='  br label %loop\nloop:\n  %iteration = phi i8 addrspace(1)* [ %iteration, %loop ], [ %arg, %entry ]\n  br i1 %cond, label %loop, label %exit\nexit:\n'
   origin='%iteration'
  if kind=='as0-roundtrip':
   body+='  %plain = addrspacecast i8 addrspace(1)* %heap to i8*\n  %managed = addrspacecast i8* %plain to i8 addrspace(1)*\n'
   origin='%managed'
  body+='  %field = getelementptr '+('' if kind=='unbounded-gep' else 'inbounds ')+'i8, i8 addrspace(1)* '+origin+', i64 '+('%index' if kind=='unbounded-gep' else '8')+'\n  %slot = bitcast i8 addrspace(1)* %field to i8 addrspace(1)* addrspace(1)*\n'
  owner='%heap' if kind=='owner-only' else origin
  if mode=='write': body+='  call void (i8 addrspace(1)*, i8 addrspace(1)*, i8 addrspace(1)* addrspace(1)*, ...) @llvm.cj.gcwrite.ref(i8 addrspace(1)* %value, i8 addrspace(1)* '+owner+', i8 addrspace(1)* addrspace(1)* %slot, i32 1)\n  ret void\n'
  else: body+='  %value = call i8 addrspace(1)* @llvm.cj.gcread.ref(i8 addrspace(1)* '+owner+', i8 addrspace(1)* addrspace(1)* %slot)\n  ret i8 addrspace(1)* %value\n'
  signature='define '+('void' if mode=='write' else 'i8 addrspace(1)*')+' @probe(i8* %type, i8 addrspace(1)* %arg, i1 %cond, i64 %index'+(', i8 addrspace(1)* %value' if mode=='write' else '')+') gc "cangjie" {\n'
  (root/('heap-domain-'+kind+'-'+mode+'.ll')).write_text(header+checks+signature+body+'}\n'+decl)
