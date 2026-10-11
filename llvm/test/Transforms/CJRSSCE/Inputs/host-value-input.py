"""Qualify the two RSSCE value modules before optimization for the host JIT.

P keeps its original layout. H changes only layout/triple; the certificate comes
from llc's TargetMachine, never from the optimized module. This bounded recipe
deliberately rejects hosts outside the x86_64 Linux layout equivalence proof.
"""
import argparse
import json
import pathlib
import re
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--llc", required=True)
    parser.add_argument("--certificate", required=True)
    parser.add_argument("input")
    args = parser.parse_args()
    records = []

    def run(argv, text=None):
        result = subprocess.run(argv, input=text, text=True, capture_output=True)
        records.append({"argv": argv, "rc": result.returncode,
                        "stdout": result.stdout, "stderr": result.stderr})
        pathlib.Path(args.certificate).write_text(json.dumps(records, indent=2))
        if result.returncode:
            sys.stderr.write(result.stderr)
            raise RuntimeError("host TargetMachine certificate failed")
        return result.stdout

    version = run([args.llc, "--version"])
    triple = re.search(r"Default target: (\S+)", version).group(1)
    if triple != "x86_64-unknown-linux-gnu":
        raise RuntimeError("host outside the proved x86_64 Linux equivalence")
    mir = run([args.llc, "-mtriple=" + triple, "-stop-before=finalize-isel",
               "-o", "-"], "define i32 @main() { ret i32 0 }\n")
    layout = re.search(r'target datalayout = "([^"]+)"', mir).group(1)
    expected = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
    if layout != expected:
        raise RuntimeError("actual TargetMachine layout differs from the proof")
    path = pathlib.Path(args.input)
    if path.name not in ("destination-read-phi.ll", "source-copy-range.ll"):
        raise RuntimeError("input outside the two proved complete modules")
    original = path.read_text()
    driver = path.with_name("Inputs") / (path.stem + "-values.ll")
    complete = original + "\n" + driver.read_text()
    ir = "\n".join(line.split(";", 1)[0] for line in complete.splitlines())
    # These modules use only AS0 integers, pointers, structs and byte arrays.
    # Reject layout-sensitive additions rather than extending the proof silently.
    if re.search(r"addrspace\s*\(|\b(?:half|bfloat|float|double|x86_fp80|fp128|ppc_fp128)\b|<|\bi(?:2|4|16|128)\b", ir):
        raise RuntimeError("layout-sensitive type outside the equivalence table")
    declared = re.findall(r"^declare .*?@([^ (]+)", ir, re.M)
    allowed = {"printf", "llvm.memcpy.p0i8.p0i8.i64"}
    if set(declared) - allowed:
        raise RuntimeError("external call outside the proved ABI")
    if "target triple" in ir:
        raise RuntimeError("unexpected preexisting triple")
    old = 'target datalayout = "e-p:64:64-i64:64-n8:16:32:64-S128"'
    if original.count(old) != 1:
        raise RuntimeError("P layout differs from the frozen input")
    qualified = original.replace(old, 'target datalayout = "' + layout +
                                 '"\ntarget triple = "' + triple + '"')
    # A textual inverse proves that functions, types, attributes and comments
    # were preserved; the unmodified driver is appended only after opt.
    assert qualified.replace('target datalayout = "' + layout +
                             '"\ntarget triple = "' + triple + '"', old) == original
    sys.stdout.write(qualified)


if __name__ == "__main__":
    main()
