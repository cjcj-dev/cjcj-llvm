from pathlib import Path
import difflib,json
p=Path('llvm/lib/CodeGen/CJBarrierLowering.cpp')
s=p.read_text()
consumer=s
for old,new in [
('      WB.storeFastPath(CI);','      if (!hasProvenHeapDestination(getPointerArg(CI)))\n        WB.storeFastPath(CI);'),
('      RB.readFastPath(CI, getPointerArg(CI));','      if (!hasProvenHeapDestination(getPointerArg(CI)))\n        RB.readFastPath(CI, getPointerArg(CI));')]:
    assert consumer.count(old)==1
    consumer=consumer.replace(old,new)
old='''      for (Value *Incoming : Phi->incoming_values())
        if (!hasHeapAllocationOrigin(Incoming, Active, Known))
          return false;
      return Phi->getNumIncomingValues() != 0;'''
new='''      for (Value *Incoming : Phi->incoming_values())
        if (hasHeapAllocationOrigin(Incoming, Active, Known))
          return true;
      return false;'''
assert s.count(old)==1
producer=s.replace(old,new)
out=Path('issue16-evidence')
for arm,value in [('consumer',consumer),('producer',producer)]:
    (out/(arm+'.diff')).write_text(''.join(difflib.unified_diff(s.splitlines(True),value.splitlines(True),fromfile='a/'+str(p),tofile='b/'+str(p))))
