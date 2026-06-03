#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys
from pathlib import Path


def run_command(cmd, root):
    print("+ " + " ".join(cmd))
    return subprocess.run(cmd, cwd=root)


def main():
    parser = argparse.ArgumentParser(description="Refresh compact AI project index and audit output.")
    parser.add_argument("root", nargs="?", default=".", help="Repository root")
    parser.add_argument("--index", default=".ai-project-index/index.json")
    parser.add_argument("--audit-output", default=".ai-project-index/audit.json")
    parser.add_argument("--fail-on-warning", action="store_true")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    script_dir = Path(__file__).resolve().parent

    generate = run_command(
        [sys.executable, str(script_dir / "generate-index.py"), str(root), "--output", args.index],
        root,
    )
    if generate.returncode != 0:
        return generate.returncode

    audit = run_command(
        [
            sys.executable,
            str(script_dir / "audit-index.py"),
            str(root),
            "--index",
            args.index,
            "--output",
            args.audit_output,
        ],
        root,
    )
    if audit.returncode != 0:
        return audit.returncode

    audit_path = root / args.audit_output
    if audit_path.is_file():
        audit_data = json.loads(audit_path.read_text(encoding="utf-8"))
        status = audit_data.get("status", "unknown")
        print(f"Refresh audit status: {status}")
        if args.fail_on_warning and status != "ok":
            return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
