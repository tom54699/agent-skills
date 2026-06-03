#!/usr/bin/env python3
import argparse
import json
import re
from pathlib import Path


def terms_for(query):
    return [t.lower() for t in re.findall(r"[A-Za-z0-9_-]+|[\u4e00-\u9fff]+", query) if t.strip()]


def field_text(file_entry, field):
    value = file_entry.get(field)
    if isinstance(value, str):
        return value
    return json.dumps(value or [], ensure_ascii=False)


def score_file(file_entry, terms, exact):
    fields = {
        "path": field_text(file_entry, "path"),
        "tags": field_text(file_entry, "tags"),
        "symbols": field_text(file_entry, "symbols"),
        "headings": field_text(file_entry, "headings"),
        "keywords": field_text(file_entry, "keywords"),
        "excerpt": field_text(file_entry, "excerpt"),
    }
    weights = {
        "path": 8,
        "tags": 6,
        "symbols": 7,
        "headings": 5,
        "keywords": 3,
        "excerpt": 1,
    }
    score = 0
    matched = []
    lower_fields = {name: text.lower() for name, text in fields.items()}
    for name, text in lower_fields.items():
        if exact and exact in text:
            score += weights[name] * 4
            matched.append(name)
        for term in terms:
            if term in text:
                score += weights[name]
                matched.append(name)
    return score, sorted(set(matched))


def snippet(file_entry, terms):
    excerpt = file_entry.get("excerpt", "")
    lower = excerpt.lower()
    positions = [lower.find(term) for term in terms if lower.find(term) >= 0]
    if not positions:
        return excerpt[:220]
    start = max(0, min(positions) - 80)
    return excerpt[start:start + 260]


def main():
    parser = argparse.ArgumentParser(description="Query compact AI project index.")
    parser.add_argument("query")
    parser.add_argument("--index", default=".ai-project-index/index.json")
    parser.add_argument("--limit", type=int, default=12)
    parser.add_argument("--include-archive", action="store_true")
    parser.add_argument("--include-changes", action="store_true")
    parser.add_argument("--include-self", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    index = json.loads(Path(args.index).read_text(encoding="utf-8"))
    terms = terms_for(args.query)
    exact = args.query.lower().strip()
    results = []
    for file_entry in index.get("files", []):
        path = file_entry["path"]
        if path.startswith("openspec/changes/archive/"):
            if not args.include_archive:
                continue
        elif not args.include_changes and path.startswith("openspec/changes/"):
            continue
        if not args.include_self and path.startswith("skills/ai-project-index/"):
            continue
        score, matched = score_file(file_entry, terms, exact)
        if score <= 0:
            continue
        results.append({
            "score": score,
            "path": path,
            "category": file_entry.get("category"),
            "language": file_entry.get("language"),
            "matchedFields": matched,
            "tags": file_entry.get("tags", []),
            "symbols": file_entry.get("symbols", [])[:8],
            "headings": file_entry.get("headings", [])[:5],
            "snippet": snippet(file_entry, terms),
        })
    results.sort(key=lambda item: (-item["score"], item["path"]))
    results = results[:args.limit]

    if args.json:
        print(json.dumps({"query": args.query, "results": results}, ensure_ascii=False, indent=2))
        return

    for item in results:
        print(f"{item['score']:>4}  {item['path']}")
        details = []
        if item["matchedFields"]:
            details.append("matched=" + ",".join(item["matchedFields"]))
        if item["tags"]:
            details.append("tags=" + ",".join(item["tags"][:8]))
        if details:
            print("      " + " ".join(details))
        if item["snippet"]:
            print("      " + item["snippet"][:240])


if __name__ == "__main__":
    main()
