#!/usr/bin/env python3
"""Compare CJIR verifier captures and bind cleared rows to proof traces.

The verifier logs remain the authority for rejected/cleared membership.  A
trace produced by ``cjir-capture`` supplies the product-helper results and
intermediate values needed to replay the admission predicate.  Missing or
unrecoverable fields fail closed and leave the row unbound.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
from collections import Counter, defaultdict
from pathlib import Path


DIAG = {
    "Bare memcpy/memmove of reference payload": "reference-payload",
    "Bare memcpy/memmove payload provenance is unknown": "unknown-provenance",
}
CALL_RE = re.compile(r"@llvm\.(memcpy|memmove)\.p(\d+)i8\.p(\d+)i8\.i(32|64)\(")
FIELDS = ["module", "function", "dst", "shape", "size", "class", "call"]
IDENTITY_FIELDS = ["module", "function", "dst", "shape", "size"]
RUN_METADATA_FIELDS = [
    "base_opt_sha256", "candidate_opt_sha256", "capture_tool_sha256",
    "capture_product_library_sha256", "capture_release_manifest_sha256",
    "capture_source_commit", "capture_source_file_sha256",
]
BINDING_FIELDS = [
    "module", "function", "dst", "shape", "size", "class", "bindable",
    "replay_result", "reason", *RUN_METADATA_FIELDS,
]


def norm(text: str) -> str:
    return " ".join(text.strip().split())


def split_args(text: str):
    out, cur, stack = [], [], []
    pairs = {")": "(", "]": "[", "}": "{", ">": "<"}
    quoted = escaped = False
    for char in text:
        if quoted:
            cur.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                quoted = False
        elif char == '"':
            quoted = True
            cur.append(char)
        elif char in "([{<":
            stack.append(char)
            cur.append(char)
        elif char in ")]}>":
            if stack and stack[-1] == pairs[char]:
                stack.pop()
            cur.append(char)
        elif char == "," and not stack:
            out.append(norm("".join(cur)))
            cur = []
        else:
            cur.append(char)
    out.append(norm("".join(cur)))
    return out


def parse_call(text: str):
    text = norm(text)
    match = CALL_RE.search(text)
    if not match:
        raise ValueError(f"unparsed intrinsic call: {text}")
    start, depth, quoted, escaped = match.end(), 1, False, False
    end = None
    for index in range(start, len(text)):
        char = text[index]
        if quoted:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                quoted = False
        elif char == '"':
            quoted = True
        elif char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                end = index
                break
    if end is None:
        raise ValueError(f"unclosed intrinsic call: {text}")
    args = split_args(text[start:end])
    if len(args) < 3:
        raise ValueError(f"too few intrinsic args: {text}")
    op, dst_as, src_as, width = match.groups()
    return {
        "dst": args[0],
        "shape": f"{op} p{dst_as}<-p{src_as} / i{width}",
        "size": re.sub(r"^i(?:32|64)\s+", "", args[2]),
        "call": text,
    }


def _load_log_dir(log_dir: Path):
    records = {}
    for log in sorted(log_dir.glob("*.log")):
        pending = []
        lines = log.read_text(errors="replace").splitlines()
        index = 0
        while index < len(lines):
            line = lines[index]
            category = next(
                (value for prefix, value in DIAG.items()
                 if line.startswith(prefix)), None)
            if category:
                if index + 1 >= len(lines):
                    raise ValueError(f"{log}: diagnostic without call")
                pending.append((category, lines[index + 1]))
                index += 2
                continue
            if line.startswith("in function "):
                function = line[len("in function "):]
                for category, call in pending:
                    parsed = parse_call(call)
                    row = {"module": log.stem, "function": function,
                           **parsed, "class": category}
                    key = tuple(row[field] for field in IDENTITY_FIELDS)
                    if key in records and records[key]["class"] != category:
                        raise ValueError(f"conflicting classes for {key}")
                    records[key] = row
                pending = []
            index += 1
        if pending:
            raise ValueError(f"{log}: unassigned diagnostics")
    return records


def load_trace_dir(trace_dir: Path):
    records = {}
    for path in sorted(trace_dir.glob("*.jsonl")):
        for line_number, line in enumerate(
                path.read_text(errors="replace").splitlines(), 1):
            if not line.strip():
                continue
            if line.startswith("CJIR_CAPTURE\t"):
                line = line.split("\t", 1)[1]
            trace = json.loads(line)
            if trace.get("schema") != "cjir-capture-v1":
                raise ValueError(f"{path}:{line_number}: unknown trace schema")
            parsed = parse_call(trace["call_ir"])
            row = {"module": trace["module"],
                   "function": trace["function"], **parsed}
            key = tuple(row[field] for field in IDENTITY_FIELDS)
            if key in records:
                raise ValueError(f"duplicate trace key {key}")
            records[key] = trace
    return records


def capture_sha256(root: Path, trace_dir: Path | None):
    digest = hashlib.sha256()
    for arm in ("base", "candidate"):
        for log in sorted((root / arm / "logs").glob("*.log")):
            digest.update(f"{arm}/{log.name}\0".encode())
            digest.update(log.read_bytes())
            digest.update(b"\0")
    if trace_dir:
        for trace in sorted(trace_dir.glob("*.jsonl")):
            digest.update(f"trace/{trace.name}\0".encode())
            digest.update(trace.read_bytes())
            digest.update(b"\0")
    return digest.hexdigest()


def write_tsv(path: Path, rows, fields=FIELDS, metadata=None):
    metadata = metadata or {}
    output_fields = [*fields, *RUN_METADATA_FIELDS]
    with path.open("w", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=output_fields, delimiter="\t")
        writer.writeheader()
        writer.writerows({
            **{field: row[field] for field in fields},
            **{field: metadata.get(field, "not_provided")
               for field in RUN_METADATA_FIELDS},
        } for row in rows)


def _unrecoverable(value):
    return (isinstance(value, dict) and
            value.get("status") == "unrecoverable")


def _uint(value, field):
    if _unrecoverable(value) or value is None:
        raise ValueError(f"{field}:unrecoverable")
    return int(value)


def _validate_range(trace, prefix: str):
    begin = _uint(trace[f"{prefix}begin_byte_offset"], f"{prefix}begin")
    end = _uint(trace[f"{prefix}copy_end"], f"{prefix}end")
    alloc = _uint(trace[f"{prefix}alloc_size"], f"{prefix}alloc")
    bounds_field = "bounds_result" if prefix == "dst_" else f"{prefix}bounds_result"
    bounds = trace[bounds_field]
    if _unrecoverable(bounds):
        raise ValueError(f"{prefix}bounds:unrecoverable")
    copy = int(trace["copy_size_operand"]["unsigned_value"])
    overflow = begin + copy > (1 << 64) - 1
    expected_end = min(begin + copy, (1 << 64) - 1)
    in_bounds = not overflow and begin <= alloc and expected_end <= alloc
    expected = {
        "copy_end_overflow": overflow,
        "in_bounds": in_bounds,
        "result": (not bounds["negative"] and
                   bounds["active_bits_le_64"] and in_bounds),
    }
    if end != expected_end:
        raise ValueError(f"{prefix}copy_end:mismatch")
    for key, value in expected.items():
        if bounds[key] != value:
            raise ValueError(f"{prefix}bounds.{key}:mismatch")
    return begin, end


def _validate_slots(trace, positions_field, overlaps_field, begin, end):
    positions = trace[positions_field]
    overlaps = trace[overlaps_field]
    if _unrecoverable(positions) or _unrecoverable(overlaps):
        raise ValueError(f"{positions_field}:unrecoverable")
    if len(positions) != len(overlaps):
        raise ValueError(f"{positions_field}:interval_count_mismatch")
    ref_size = int(trace["gc_pointer_size"])
    any_overlap = False
    for raw_pos, interval in zip(positions, overlaps):
        pos = int(raw_pos)
        overflow = pos + ref_size > (1 << 64) - 1
        slot_end = min(pos + ref_size, (1 << 64) - 1)
        overlap = not overflow and pos < end and begin < slot_end
        expected = {
            "slot_begin": str(pos), "slot_end": str(slot_end),
            "slot_end_overflow": overflow, "copy_begin": str(begin),
            "copy_end": str(end), "overlap": overlap,
        }
        if interval != expected:
            raise ValueError(f"{overlaps_field}:mismatch")
        any_overlap |= overlap
    return any_overlap


def replay_trace(trace):
    """Return (bindable, replay-result, reason) and fail closed."""
    required = [
        "dst_malloc_array_root", "typeinfo_global", "related_layout_type",
        "related_layout_ir", "array_length", "element_stride_operand",
        "layout_element_alloc_size", "length_times_stride", "dst_gep_steps",
        "dst_begin_byte_offset", "dst_copy_end", "dst_alloc_size",
        "bounds_result", "src_operand_ir", "src_base_ir", "src_complete_type",
        "contains_gc_ptr_input_type", "contains_gc_ptr_result",
        "gc_slot_positions", "gc_pointer_size", "slot_overlap_intervals",
        "src_contains_gc_ptr_input_type", "src_contains_gc_ptr_result",
        "src_gc_slot_positions",
        "src_slot_overlap_intervals", "src_begin_byte_offset", "src_copy_end",
        "src_alloc_size", "src_bounds_result", "copy_size_operand",
    ]
    try:
        missing = [field for field in required if field not in trace]
        if missing:
            raise ValueError("missing:" + ",".join(missing))
        for field in required:
            if _unrecoverable(trace[field]):
                reason = trace[field].get("reason", "unknown")
                raise ValueError(f"{field}:unrecoverable:{reason}")
        if trace["dst_malloc_array_root"].get("status") != "recovered":
            raise ValueError("dst_malloc_array_root:not_recovered")

        count = int(trace["array_length"]["unsigned_value"])
        stride = int(trace["element_stride_operand"]["unsigned_value"])
        layout_size = int(trace["layout_element_alloc_size"])
        arithmetic = trace["length_times_stride"]
        overflow = stride != 0 and count > ((1 << 64) - 1) // stride
        product = min(count * stride, (1 << 64) - 1)
        if arithmetic != {"overflow": overflow, "result": str(product)}:
            raise ValueError("length_times_stride:mismatch")
        if overflow or stride != layout_size:
            raise ValueError("array_layout_arithmetic:invalid")

        dst_begin, dst_end = _validate_range(trace, "dst_")
        src_begin, src_end = _validate_range(trace, "src_")
        copy = int(trace["copy_size_operand"]["unsigned_value"])
        relative = dst_begin - 16
        whole_payload = relative == 0 and copy == product
        one_element = (relative >= 0 and stride != 0 and copy == stride and
                       relative % stride == 0 and relative // stride < count)
        if not whole_payload and not one_element:
            raise ValueError("malloc_array_range:not_whole_payload_or_element")

        dst_overlap = _validate_slots(
            trace, "gc_slot_positions", "slot_overlap_intervals",
            dst_begin, dst_end)
        src_overlap = _validate_slots(
            trace, "src_gc_slot_positions", "src_slot_overlap_intervals",
            src_begin, src_end)
        dst_contains = trace["contains_gc_ptr_result"]
        src_contains = trace["src_contains_gc_ptr_result"]
        if trace["src_contains_gc_ptr_input_type"] != trace["src_complete_type"]:
            raise ValueError("src_contains_gc_ptr_input_type:mismatch")
        if not isinstance(dst_contains, bool) or not isinstance(src_contains, bool):
            raise ValueError("contains_gc_ptr_result:not_boolean")
        if not dst_contains and trace["gc_slot_positions"]:
            raise ValueError("dst_slots_nonempty_when_contains_false")
        if not src_contains and trace["src_gc_slot_positions"]:
            raise ValueError("src_slots_nonempty_when_contains_false")
        no_reference = ((not dst_contains or not dst_overlap) and
                        (not src_contains or not src_overlap))
        return True, "NoReference" if no_reference else "ContainsReference", ""
    except (KeyError, TypeError, ValueError) as error:
        return False, "Unknown", str(error)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path,
                        help="capture root containing base/ and candidate/")
    parser.add_argument("--trace-dir", type=Path,
                        help="cjir-capture JSONL files keyed by module")
    parser.add_argument("--base-opt-sha256", default="not_provided")
    parser.add_argument("--candidate-opt-sha256", default="not_provided")
    parser.add_argument("--capture-tool-sha256", default="not_provided")
    parser.add_argument("--capture-product-library-sha256",
                        default="not_provided")
    parser.add_argument("--capture-release-manifest-sha256",
                        default="not_provided")
    parser.add_argument("--capture-source-commit", default="not_provided")
    parser.add_argument("--capture-source-file-sha256", default="not_provided")
    args = parser.parse_args()
    root = args.root
    base = _load_log_dir(root / "base" / "logs")
    candidate = _load_log_dir(root / "candidate" / "logs")
    traces = load_trace_dir(args.trace_dir) if args.trace_dir else {}
    input_sha = capture_sha256(root, args.trace_dir)
    base_keys, candidate_keys = set(base), set(candidate)
    new = candidate_keys - base_keys
    cleared = base_keys - candidate_keys
    migrated = {key for key in base_keys & candidate_keys
                if base[key]["class"] != candidate[key]["class"]}
    output = root / "analysis"
    output.mkdir(exist_ok=True)
    metadata = {field: getattr(args, field) for field in RUN_METADATA_FIELDS}
    write_tsv(output / "base.normalized.tsv",
              [base[key] for key in sorted(base_keys)], metadata=metadata)
    write_tsv(output / "candidate.normalized.tsv",
              [candidate[key] for key in sorted(candidate_keys)],
              metadata=metadata)
    write_tsv(output / "NEW.tsv", [candidate[key] for key in sorted(new)],
              metadata=metadata)
    write_tsv(output / "CLEARED.tsv", [base[key] for key in sorted(cleared)],
              metadata=metadata)
    write_tsv(output / "MIGRATED.tsv", [
        {**candidate[key],
         "class": f"{base[key]['class']}->{candidate[key]['class']}"}
        for key in sorted(migrated)
    ], metadata=metadata)

    binding_rows = []
    binding_records = []
    distribution = Counter()
    for key in sorted(cleared):
        row = base[key]
        trace = traces.get(key)
        if trace is None:
            bindable, replay, reason = False, "Unknown", "missing_trace"
        else:
            bindable, replay, reason = replay_trace(trace)
            binding_records.append({"identity": row, "trace": trace,
                                    "bindable": bindable,
                                    "replay_result": replay,
                                    "reason": reason})
        binding_rows.append({**row, "bindable": str(bindable).lower(),
                             "replay_result": replay, "reason": reason,
                             **metadata})
        if bindable:
            distribution[(row["function"], replay)] += 1
    write_tsv(output / "BINDING.tsv", binding_rows,
              BINDING_FIELDS[:-len(RUN_METADATA_FIELDS)], metadata=metadata)
    with (output / "CLEARED.binding.jsonl").open("w") as stream:
        for record in binding_records:
            stream.write(json.dumps(record, sort_keys=True) + "\n")
    with (output / "binding-distribution.tsv").open("w", newline="") as stream:
        writer = csv.writer(stream, delimiter="\t")
        writer.writerow(["function", "replay_result", "count",
                         *RUN_METADATA_FIELDS])
        for (function, replay), count in sorted(distribution.items()):
            writer.writerow([function, replay, count,
                             *(metadata[field] for field in RUN_METADATA_FIELDS)])

    bindable_count = sum(row["bindable"] == "true" for row in binding_rows)
    no_reference_count = sum(
        row["bindable"] == "true" and row["replay_result"] == "NoReference"
        for row in binding_rows)
    summary = {
        "input_sha256": input_sha, "base": len(base),
        "candidate": len(candidate), "NEW": len(new),
        "CLEARED": len(cleared), "MIGRATED": len(migrated),
        "trace_records": len(traces), "bindable": bindable_count,
        "replay_no_reference": no_reference_count,
        "unbound": len(cleared) - bindable_count,
        **metadata,
    }
    (output / "summary.txt").write_text(
        "".join(f"{key}={value}\n" for key, value in summary.items()))
    (output / "input.sha256").write_text(
        f"{input_sha}  capture-log-and-trace-set\n")
    print(" ".join(f"{key}={value}" for key, value in summary.items()
                   if key != "input_sha256"))


if __name__ == "__main__":
    main()
