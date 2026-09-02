#!/usr/bin/env python3
"""Regression tests for cjir_capture_diff.py."""

from __future__ import annotations

import json
import hashlib
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from cjir_capture_run import sha256 as file_sha256
from cjir_capture_diff import capture_sha256


SCRIPT = Path(__file__).with_name("cjir_capture_diff.py")
UNKNOWN = "Bare memcpy/memmove payload provenance is unknown"
REFERENCE = "Bare memcpy/memmove of reference payload"
CALL = ("call void @llvm.memcpy.p1i8.p0i8.i64("
        "i8 addrspace(1)* %d, i8* %src, i64 8, i1 false)")


def diagnostic(category: str) -> str:
    return f"{category}; detail\n  {CALL}\nin function f\n"


def trace(overlap=False, src_unrecoverable=False):
    positions = ["16"] if overlap else []
    intervals = ([{"slot_begin": "16", "slot_end": "24",
                   "slot_end_overflow": False, "copy_begin": "16",
                   "copy_end": "24", "overlap": True}]
                 if overlap else [])
    source_type = ({"status": "unrecoverable", "reason": "bare_i8_carrier"}
                   if src_unrecoverable else "i64")
    return {
        "schema": "cjir-capture-v1", "module": "x", "function": "f",
        "call_ir": CALL, "dst_operand_ir": "i8 addrspace(1)* %d",
        "src_operand_ir": "i8* %src", "copy_size_operand": {
            "ir": "i64 8", "unsigned_value": "8"},
        "dst_malloc_array_root": {"status": "recovered", "call_ssa": "%a",
                                  "basic_block": "%entry"},
        "typeinfo_global": "ti", "related_layout_type": "layout",
        "related_layout_ir": "%layout = type { i64, [0 x i64] }",
        "array_length": {"ir": "i64 1", "unsigned_value": "1"},
        "element_stride_operand": {"ir": "i64 8", "unsigned_value": "8"},
        "layout_element_alloc_size": "8",
        "length_times_stride": {"overflow": False, "result": "8"},
        "dst_gep_steps": [], "dst_begin_byte_offset": "16",
        "dst_copy_end": "24", "dst_alloc_size": "24",
        "bounds_result": {"negative": False, "active_bits": 5,
                          "active_bits_le_64": True,
                          "length_times_stride_overflow": False,
                          "alloc_size_overflow": False,
                          "copy_end_overflow": False, "in_bounds": True,
                          "result": True},
        "src_base_ir": "%src", "src_complete_type": source_type,
        "src_contains_gc_ptr_input_type": source_type,
        "src_contains_gc_ptr_result": False,
        "src_gc_slot_positions": [], "src_slot_overlap_intervals": [],
        "src_begin_byte_offset": "0", "src_copy_end": "8",
        "src_alloc_size": "8",
        "src_bounds_result": {"negative": False, "active_bits": 0,
                              "active_bits_le_64": True,
                              "copy_end_overflow": False,
                              "in_bounds": True, "result": True},
        "contains_gc_ptr_input_type": "i64",
        "contains_gc_ptr_result": overlap,
        "gc_slot_positions": positions, "gc_pointer_size": "8",
        "slot_overlap_intervals": intervals,
    }


class CaptureDiffTest(unittest.TestCase):
    def run_diff(self, base: str, candidate: str, trace_record=None):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        for arm, text in (("base", base), ("candidate", candidate)):
            log_dir = root / arm / "logs"
            log_dir.mkdir(parents=True)
            (log_dir / "x.log").write_text(text)
        command = [sys.executable, str(SCRIPT), str(root)]
        if trace_record is not None:
            trace_dir = root / "traces"
            trace_dir.mkdir()
            (trace_dir / "x.jsonl").write_text(
                json.dumps(trace_record) + "\n")
            command += ["--trace-dir", str(trace_dir)]
        result = subprocess.run(command, check=False, text=True,
                                capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        summary = dict(
            line.split("=", 1) for line in
            (root / "analysis" / "summary.txt").read_text().splitlines())
        return root, summary

    def test_class_change_is_migration(self):
        _, summary = self.run_diff(diagnostic(UNKNOWN), diagnostic(REFERENCE))
        self.assertEqual(summary["NEW"], "0")
        self.assertEqual(summary["CLEARED"], "0")
        self.assertEqual(summary["MIGRATED"], "1")

    def test_new_record_remains_new(self):
        _, summary = self.run_diff("", diagnostic(UNKNOWN))
        self.assertEqual(summary["NEW"], "1")
        self.assertEqual(summary["CLEARED"], "0")

    def test_complete_trace_binds_and_replays_no_reference(self):
        _, summary = self.run_diff(diagnostic(UNKNOWN), "", trace())
        self.assertEqual(summary["bindable"], "1")
        self.assertEqual(summary["replay_no_reference"], "1")
        self.assertEqual(summary["unbound"], "0")

    def test_positive_gc_slot_overlap_is_recorded(self):
        root, summary = self.run_diff(diagnostic(UNKNOWN), "", trace(True))
        self.assertEqual(summary["bindable"], "1")
        self.assertEqual(summary["replay_no_reference"], "0")
        binding = (root / "analysis" / "BINDING.tsv").read_text()
        self.assertIn("ContainsReference", binding)

    def test_unrecoverable_source_fails_closed(self):
        root, summary = self.run_diff(
            diagnostic(UNKNOWN), "", trace(src_unrecoverable=True))
        self.assertEqual(summary["bindable"], "0")
        self.assertEqual(summary["unbound"], "1")
        binding = (root / "analysis" / "BINDING.tsv").read_text()
        self.assertIn("src_complete_type:unrecoverable:bare_i8_carrier", binding)

    def test_fault_before_after_trace_inputs_differ(self):
        """The analyzer input hash must bind a real before/after mutation."""
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        for arm in ("base", "candidate"):
            log_dir = root / arm / "logs"
            log_dir.mkdir(parents=True)
            (log_dir / "x.log").write_text(diagnostic(UNKNOWN) if arm == "base" else "")
        before_dir = root / "trace-before"
        after_dir = root / "trace-after"
        before_dir.mkdir()
        after_dir.mkdir()
        before = trace()
        after = json.loads(json.dumps(before))
        after["bounds_result"]["in_bounds"] = False
        (before_dir / "x.jsonl").write_text(json.dumps(before) + "\n")
        (after_dir / "x.jsonl").write_text(json.dumps(after) + "\n")
        before_sha = capture_sha256(root, before_dir)
        after_sha = capture_sha256(root, after_dir)
        self.assertNotEqual(before_sha, after_sha)
        self.assertNotEqual(
            hashlib.sha256((before_dir / "x.jsonl").read_bytes()).hexdigest(),
            hashlib.sha256((after_dir / "x.jsonl").read_bytes()).hexdigest())

    def test_release_manifest_binds_packaged_so_and_rejects_tamper(self):
        """The runner accepts only the SO whose packaged hash is verified."""
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        release = root / "release"
        (release / "bin").mkdir(parents=True)
        (release / "lib").mkdir()
        tool = release / "bin" / "cjir-capture"
        tool.write_text("#!/usr/bin/env python3\nprint('CJIR_CAPTURE\\t{}')\n")
        tool.chmod(tool.stat().st_mode | stat.S_IXUSR)
        library = release / "lib" / "libLLVM-15.so"
        library.write_bytes(b"packaged-product-library-v1")
        manifest = release / "MANIFEST.sha256"
        manifest.write_text(
            f"{file_sha256(tool)}  bin/cjir-capture\n"
            f"{file_sha256(library)}  lib/libLLVM-15.so\n"
            "# source_commit: test\n# source_file_sha256: test\n")
        capture = root / "input.ll"
        capture.write_text("; input\n")
        inventory = root / "inventory.tsv"
        inventory.write_text(f"module\tcapture\nx\t{capture}\n")
        output = root / "output"
        command = [sys.executable, str(Path(__file__).with_name("cjir_capture_run.py")),
                   "--inventory", str(inventory), "--output-dir", str(output),
                   "--release", str(release)]
        good = subprocess.run(command, text=True, capture_output=True,
                              check=False)
        self.assertEqual(good.returncode, 0, good.stderr)
        row = (output / "trace-manifest.tsv").read_text().splitlines()[1].split("\t")
        header = (output / "trace-manifest.tsv").read_text().splitlines()[0].split("\t")
        values = dict(zip(header, row))
        self.assertEqual(values["capture_product_library_sha256"], file_sha256(library))
        self.assertEqual(values["capture_source_commit"], "test")
        self.assertEqual(values["capture_source_file_sha256"], "test")
        original = library.read_bytes()
        library.write_bytes(bytes([original[0] ^ 1]) + original[1:])
        bad = subprocess.run(command, text=True, capture_output=True, check=False)
        self.assertNotEqual(bad.returncode, 0)
        library.write_bytes(original)
        restored = subprocess.run(command, text=True, capture_output=True,
                                  check=False)
        self.assertEqual(restored.returncode, 0, restored.stderr)


if __name__ == "__main__":
    unittest.main()
