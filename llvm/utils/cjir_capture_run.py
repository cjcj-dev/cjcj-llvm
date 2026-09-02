#!/usr/bin/env python3
"""Run cjir-capture over a verifier-sweep inventory with identity records."""

from __future__ import annotations

import argparse
import csv
import hashlib
import os
import re
import subprocess
import sys
from pathlib import Path


MANIFEST_FILES = ("bin/cjir-capture", "lib/libLLVM-15.so")
MANIFEST_LINE = re.compile(r"^([0-9a-fA-F]{64})  (.+)$")
MANIFEST_METADATA = {
    "source_commit": "capture_source_commit",
    "source_file_sha256": "capture_source_file_sha256",
}


def sha256(path: Path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_release(release: Path):
    """Run sha256sum -c and return the two packaged file hashes."""
    release = release.resolve()
    manifest = release / "MANIFEST.sha256"
    if not manifest.is_file():
        raise ValueError(f"missing release manifest: {manifest}")
    check = subprocess.run(
        ["sha256sum", "-c", manifest.name], cwd=release,
        text=True, capture_output=True, check=False)
    if check.returncode != 0:
        detail = (check.stdout + check.stderr).strip()
        raise ValueError(
            f"release manifest verification failed (rc={check.returncode}): "
            f"{detail}")
    hashes = {}
    metadata = {}
    for line in manifest.read_text().splitlines():
        match = MANIFEST_LINE.match(line.strip())
        if match:
            hashes[match.group(2)] = match.group(1)
        elif line.startswith("# ") and ":" in line:
            key, value = line[2:].split(":", 1)
            if key in MANIFEST_METADATA:
                metadata[MANIFEST_METADATA[key]] = value.strip()
    missing = [name for name in MANIFEST_FILES if name not in hashes]
    if missing:
        raise ValueError("manifest missing entries: " + ", ".join(missing))
    for name in MANIFEST_FILES:
        if not (release / name).is_file():
            raise ValueError(f"manifest entry is not a file: {release / name}")
    return (manifest, {name: hashes[name] for name in MANIFEST_FILES},
            metadata)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--inventory", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--release", type=Path, required=True,
                        help="self-contained release with bin/, lib/, and MANIFEST.sha256")
    args = parser.parse_args()
    try:
        manifest, release_hashes, release_metadata = validate_release(args.release)
    except ValueError as error:
        print(f"cjir-capture-run: {error}", file=sys.stderr)
        return 2
    args.output_dir.mkdir(parents=True, exist_ok=True)
    release = args.release.resolve()
    tool = release / "bin/cjir-capture"
    tool_sha = release_hashes["bin/cjir-capture"]
    library_sha = release_hashes["lib/libLLVM-15.so"]
    manifest_sha = sha256(manifest)
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
                    [str(tool), f"--module-name={module}", str(capture)],
                    stdout=stdout, stderr=error, check=False,
                    env={key: value for key, value in os.environ.items()
                         if key not in ("LD_LIBRARY_PATH", "LD_PRELOAD")})
            records = sum(
                1 for line in output.read_text(errors="replace").splitlines()
                if line.startswith("CJIR_CAPTURE\t"))
            rows.append({
                "module": module, "capture": str(capture),
                "capture_sha256": sha256(capture), "rc": result.returncode,
                "records": records, "capture_tool_sha256": tool_sha,
                "capture_product_library_sha256": library_sha,
                "capture_release_manifest_sha256": manifest_sha,
                **release_metadata,
            })
    manifest = args.output_dir / "trace-manifest.tsv"
    with manifest.open("w", newline="") as stream:
        fields = list(rows[0]) if rows else [
            "module", "capture", "capture_sha256", "rc", "records",
            "capture_tool_sha256", "capture_product_library_sha256",
            "capture_release_manifest_sha256", "capture_source_commit",
            "capture_source_file_sha256"]
        writer = csv.DictWriter(stream, fieldnames=fields, delimiter="\t")
        writer.writeheader()
        writer.writerows(rows)
    failures = [row for row in rows if row["rc"] != 0]
    print(f"modules={len(rows)} failures={len(failures)} "
          f"records={sum(row['records'] for row in rows)}")
    return bool(failures)


if __name__ == "__main__":
    raise SystemExit(main())
