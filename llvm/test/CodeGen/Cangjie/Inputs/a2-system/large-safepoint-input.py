#!/usr/bin/env python3
"""Preparation recipe only. Do not run before a separately frozen allowance.

Each empty sideeffect asm is a real MI despite emitting no bytes. This targets
AArch64's source predicate getInstructionCount()*4 > 0x7FFFF, rather than hoping
that a large source file takes a special branch. Generated IR byte/hash binding
is deliberately a missing precondition in the source-stage execution plan.
"""
from pathlib import Path
import argparse

p = argparse.ArgumentParser()
p.add_argument('--output', required=True)
a = p.parse_args()
header = '''declare token @llvm.cj.gc.statepoint(...)
declare void @CJ_MCC_HandleSafepoint()
@CJ_MCC_HandleSafepoint.CJStubGV = external global i8*
define void @test() noinline optnone gc "cangjie" {
'''
body = '  call void asm sideeffect "", ""()\n' * 131073
footer = '''  %s = call token (...) @llvm.cj.gc.statepoint(i64 3, i32 0, void ()* @CJ_MCC_HandleSafepoint, i32 0, i32 0)
  ret void
}
!llvm.module.flags = !{!0}
!0 = !{i32 1, !"Cangjie_PACKAGE_ID", !"a2_system"}
'''
Path(a.output).write_text(header + body + footer)
