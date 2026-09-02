#!/usr/bin/env python3
"""Run cjir-capture over a verifier-sweep inventory with identity records."""

from __future__ import annotations

import argparse
import csv
import hashlib
import subprocess
from pathlib import Path


def sha256(path: Path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--tool", type=Path, required=True)
    parser.add_argument("--inventory", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--product-library", type=Path, required=True,
                        help="libLLVM containing the product helpers")
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    tool_sha = sha256(args.tool)
    library_sha = sha256(args.product_library)
    rows = []
    with args.inventory.open(newline="") as stream:
        inventory = csv.DictReader(stream, delimiter="\t")
        for item in inventory:
            module = item["module"]
            capture = Path(item["capture"])
            output = args.output_dir / f"{module}.jsonl"
            stderr = args.output_dir / f"{module}.stderr"
            with output.open("wb") as stdout, stderr.open("wb") as error:
                result = subprocess.run(
                    [str(args.tool), f"--module-name={module}", str(capture)],
                    stdout=stdout, stderr=error, check=False)
            records = sum(
                1 for line in output.read_text(errors="replace").splitlines()
                if line.startswith("CJIR_CAPTURE\t"))
            rows.append({
                "module": module, "capture": str(capture),
                "capture_sha256": sha256(capture), "rc": result.returncode,
                "records": records, "capture_tool_sha256": tool_sha,
                "capture_product_library_sha256": library_sha,
            })
    manifest = args.output_dir / "trace-manifest.tsv"
    with manifest.open("w", newline="") as stream:
        fields = list(rows[0]) if rows else [
            "module", "capture", "capture_sha256", "rc", "records",
            "capture_tool_sha256", "capture_product_library_sha256"]
        writer = csv.DictWriter(stream, fieldnames=fields, delimiter="\t")
        writer.writeheader()
        writer.writerows(rows)
    failures = [row for row in rows if row["rc"] != 0]
    print(f"modules={len(rows)} failures={len(failures)} "
          f"records={sum(row['records'] for row in rows)}")
    return bool(failures)


if __name__ == "__main__":
    raise SystemExit(main())
