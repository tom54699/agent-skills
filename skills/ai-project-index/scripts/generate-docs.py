#!/usr/bin/env python3
import argparse
import json
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path


DRAFT_HEADER = """<!-- GENERATED DRAFT: review before treating as source of truth. -->
"""

EXCLUDED_DOC_CATEGORIES = {"active-change", "archived-change"}
EXCLUDED_DOC_PATHS = ("docs/generated/",)


def main():
    parser = argparse.ArgumentParser(description="Generate draft docs from compact AI project index.")
    parser.add_argument("--index", default=".ai-project-index/index.json")
    parser.add_argument("--output-dir", default="docs/generated")
    args = parser.parse_args()

    index = json.loads(Path(args.index).read_text(encoding="utf-8"))
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    generated_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()

    doc_files = [
        file_entry for file_entry in index.get("files", [])
        if file_entry.get("category") not in EXCLUDED_DOC_CATEGORIES
        and not file_entry.get("path", "").startswith(EXCLUDED_DOC_PATHS)
    ]

    by_category = defaultdict(list)
    for file_entry in doc_files:
        by_category[file_entry.get("category", "unknown")].append(file_entry)

    project_map = [
        DRAFT_HEADER,
        "# Generated Project Map",
        "",
        f"Generated at: `{generated_at}`",
        "",
        "This file is generated from `.ai-project-index/index.json` and must be reviewed before use as source of truth.",
        "Archived and active OpenSpec changes are intentionally omitted from this quick map.",
        "",
    ]
    for category in sorted(by_category):
        project_map.append(f"## {category}")
        project_map.append("")
        for file_entry in sorted(by_category[category], key=lambda item: item["path"])[:80]:
            tags = ", ".join(file_entry.get("tags", [])[:8])
            project_map.append(f"- `{file_entry['path']}` ({file_entry.get('language')}; {tags})")
        project_map.append("")

    business = [
        DRAFT_HEADER,
        "# Generated Business Logic Draft",
        "",
        f"Generated at: `{generated_at}`",
        "",
        "This draft lists likely business-relevant files from index tags and headings. Verify against source, OpenSpec specs, docs, and tests.",
        "",
    ]
    focus_tags = {"laravel-api-docs", "openapi", "apidog", "candidate", "query-parameter", "redoc", "sync-history", "conflict"}
    focused = [
        f for f in doc_files
        if focus_tags.intersection(set(f.get("tags", [])))
    ]
    for file_entry in sorted(focused, key=lambda item: item["path"]):
        business.append(f"## `{file_entry['path']}`")
        business.append("")
        business.append(f"- Category: `{file_entry.get('category')}`")
        business.append(f"- Tags: {', '.join(file_entry.get('tags', []))}")
        symbols = ", ".join(s["name"] for s in file_entry.get("symbols", [])[:12])
        if symbols:
            business.append(f"- Symbols: {symbols}")
        headings = "; ".join(h["text"] for h in file_entry.get("headings", [])[:6])
        if headings:
            business.append(f"- Headings: {headings}")
        business.append("")

    (output_dir / "project-map.md").write_text("\n".join(project_map), encoding="utf-8")
    (output_dir / "business-logic-draft.md").write_text("\n".join(business), encoding="utf-8")
    print(f"Wrote {output_dir / 'project-map.md'}")
    print(f"Wrote {output_dir / 'business-logic-draft.md'}")


if __name__ == "__main__":
    main()
