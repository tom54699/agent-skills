#!/usr/bin/env python3
import argparse
import fnmatch
import json
import subprocess
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

EXPECTED_SCHEMA_VERSION = "1.0.0"


def git_commit(root):
    try:
        return subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"]).decode().strip()
    except Exception:
        return None


def expand_existing(root, pattern):
    matches = sorted(root.glob(pattern))
    return [p.relative_to(root).as_posix() for p in matches if p.is_file()]


def pattern_covered(paths, pattern):
    if any(ch in pattern for ch in "*?["):
        return any(fnmatch.fnmatch(path, pattern) for path in paths)
    return pattern in paths


def warning_audit(args, root, reason, detail):
    audit = {
        "version": EXPECTED_SCHEMA_VERSION,
        "generatedAt": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "indexPath": args.index,
        "status": "warning",
        "summary": {
            "fileCount": 0,
            "duplicatePathCount": 0,
            "missingIndexedFileCount": 0,
            "missingExpectedPatternCount": 0,
            "stale": False,
            "schemaErrorCount": 1,
        },
        "coverage": [],
        "integrity": {
            "duplicatePaths": [],
            "missingIndexedFiles": [],
            "indexedCommit": None,
            "currentCommit": git_commit(root),
        },
        "schemaErrors": [
            {
                "reason": reason,
                "detail": detail,
            }
        ],
    }
    output = root / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(audit, ensure_ascii=False, indent=2), encoding="utf-8")
    print("Audit status: warning")
    print(json.dumps(audit["summary"], ensure_ascii=False, indent=2))
    print(f"Schema error: {reason}")


def load_index(index_path):
    if not index_path.is_file():
        return None, ("missing_index", f"{index_path} does not exist")
    try:
        return json.loads(index_path.read_text(encoding="utf-8")), None
    except json.JSONDecodeError as exc:
        return None, ("invalid_json", str(exc))


def main():
    parser = argparse.ArgumentParser(description="Audit compact AI project index.")
    parser.add_argument("root", nargs="?", default=".")
    parser.add_argument("--index", default=".ai-project-index/index.json")
    parser.add_argument("--output", default=".ai-project-index/audit.json")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    index_path = root / args.index
    index, read_error = load_index(index_path)
    if read_error:
        warning_audit(args, root, read_error[0], read_error[1])
        return

    schema_errors = []
    if not isinstance(index, dict):
        warning_audit(args, root, "invalid_structure", "index root must be an object")
        return

    index_version = index.get("version")
    if index_version is not None and index_version != EXPECTED_SCHEMA_VERSION:
        warning_audit(
            args,
            root,
            "version_mismatch",
            f"index.json version {index_version!r} does not match expected {EXPECTED_SCHEMA_VERSION!r}",
        )
        return

    files = index.get("files", [])
    if not isinstance(files, list):
        schema_errors.append({"reason": "invalid_files", "detail": "files must be an array"})
        files = []

    valid_files = []
    for file_entry in files:
        if not isinstance(file_entry, dict) or not isinstance(file_entry.get("path"), str):
            schema_errors.append({"reason": "invalid_file_entry", "detail": repr(file_entry)[:200]})
            continue
        valid_files.append(file_entry)

    files = valid_files
    paths = [f["path"] for f in files]
    path_set = set(paths)
    duplicate_paths = sorted(path for path, count in Counter(paths).items() if count > 1)
    missing_indexed_files = sorted(path for path in paths if not (root / path).is_file())
    expected = index.get("scan", {}).get("expectedCoverage", [])

    coverage = []
    for pattern in expected:
        existing = expand_existing(root, pattern)
        covered = pattern_covered(path_set, pattern)
        coverage.append({
            "pattern": pattern,
            "existingMatches": existing,
            "covered": covered,
            "coveredMatches": sorted(path for path in paths if fnmatch.fnmatch(path, pattern)),
        })

    missing_expected = [item for item in coverage if item["existingMatches"] and not item["covered"]]
    current_commit = git_commit(root)
    indexed_commit = index.get("project", {}).get("gitCommitHash")
    stale = bool(current_commit and indexed_commit and current_commit != indexed_commit)

    audit = {
        "version": EXPECTED_SCHEMA_VERSION,
        "generatedAt": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "indexPath": args.index,
        "status": "ok",
        "summary": {
            "fileCount": len(files),
            "duplicatePathCount": len(duplicate_paths),
            "missingIndexedFileCount": len(missing_indexed_files),
            "missingExpectedPatternCount": len(missing_expected),
            "stale": stale,
            "schemaErrorCount": len(schema_errors),
        },
        "coverage": coverage,
        "integrity": {
            "duplicatePaths": duplicate_paths,
            "missingIndexedFiles": missing_indexed_files,
            "indexedCommit": indexed_commit,
            "currentCommit": current_commit,
        },
        "schemaErrors": schema_errors,
    }
    if duplicate_paths or missing_indexed_files or missing_expected or stale or not files or schema_errors:
        audit["status"] = "warning"

    output = root / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(audit, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"Audit status: {audit['status']}")
    print(json.dumps(audit["summary"], ensure_ascii=False, indent=2))
    if missing_expected:
        print("Missing expected coverage:")
        for item in missing_expected:
            print(f"  - {item['pattern']}")
    if schema_errors:
        print("Schema errors:")
        for item in schema_errors:
            print(f"  - {item['reason']}: {item['detail']}")


if __name__ == "__main__":
    main()
