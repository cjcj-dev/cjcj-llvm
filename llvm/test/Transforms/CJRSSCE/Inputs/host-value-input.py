"""Qualify the two RSSCE value modules before optimization for the host JIT.

P keeps its original layout. H changes only layout/triple; the certificate comes
from llc's TargetMachine, never from the optimized module. This bounded recipe
deliberately rejects hosts outside the x86_64 Linux layout equivalence proof.
"""
import argparse
import hashlib
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
    path = pathlib.Path(args.input)
    # This is a certificate for two audited complete inputs, not an IR validator.
    # Bind every byte of both the module and its value consumer: inline assembly,
    # target attributes, private-symbol references and altered drivers all need
    # a new equivalence proof before they can cross the P/H boundary.
    identities = {
        "source-copy-range.ll": (
            "2bf64c97d4c14862d58e344b4cba6c7c52a8c2b95a43436f4a348c3813ada3b2",
            "ef67cd425b0128ccba41541f02378a8f5ccf1d88a4a2fe9a7e6f499085296a9b"),
        "destination-read-phi.ll": (
            "2a541d483c2960703f5c985ad118d3dbfb66d46b4bf3a402450a0506b5801fce",
            "e15c988a2cab79be0594a5f593ac0a23f9dc8369d09431a173c5ec4703a168ba"),
    }
    expected_identity = identities.get(path.name)
    if expected_identity is None:
        raise RuntimeError("input outside the two proved complete modules")
    driver = path.with_name("Inputs") / (path.stem + "-values.ll")
    actual_identity = (hashlib.sha256(path.read_bytes()).hexdigest(),
                       hashlib.sha256(driver.read_bytes()).hexdigest())
    if actual_identity != expected_identity:
        raise RuntimeError("complete module/driver identity outside the P/H proof")
    original = path.read_text()

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
