#!/usr/bin/env python3
import argparse
import fnmatch
import hashlib
import json
import os
import re
import subprocess
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path


DEFAULT_CONFIG = {
    "includePaths": [
        "AGENTS.md",
        ".codex/skills/openspec-*/SKILL.md"
    ],
    "excludePaths": [
        "docs/generated/**"
    ],
    "expectedCoverage": [
        "skills/laravel-api-docs/SKILL.md",
        "skills/laravel-api-docs/bin/infer-candidates.php",
        "skills/laravel-api-docs/bin/gen-openapi.php",
        "skills/laravel-api-docs/src/InferCandidates/Analyzer.php",
        "skills/laravel-api-docs/src/OpenApiGenerator/OpenApiGenerator.php",
        "openspec/specs/*.md",
        "docs/*.md",
        "tests/*.php",
        ".codex/skills/openspec-*/SKILL.md",
        "AGENTS.md",
        "CLAUDE.md"
    ]
}

IGNORE_DIRS = {
    ".git",
    ".ai-project-index",
    ".understand-anything",
    "node_modules",
    "vendor",
    "dist",
    "build",
    ".idea",
    ".vscode",
}

TEXT_EXTENSIONS = {
    ".md", ".php", ".sh", ".bash", ".zsh", ".yaml", ".yml", ".json",
    ".jsonc", ".toml", ".txt", ".py", ".js", ".ts", ".tsx", ".html", ".css"
}


def run_git(root, args):
    try:
        result = subprocess.run(
            ["git", "-C", str(root), *args],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        return result.stdout
    except (subprocess.CalledProcessError, FileNotFoundError):
        return b""


def git_files(root):
    raw = run_git(root, ["ls-files", "-z", "-co", "--exclude-standard"])
    if not raw:
        return []
    return [p.decode("utf-8", "replace") for p in raw.split(b"\0") if p]


def walk_files(root):
    out = []
    for current, dirs, files in os.walk(root):
        dirs[:] = sorted(d for d in dirs if d not in IGNORE_DIRS)
        for name in sorted(files):
            path = Path(current, name)
            rel = path.relative_to(root).as_posix()
            if any(part in IGNORE_DIRS for part in Path(rel).parts):
                continue
            out.append(rel)
    return out


def load_config(root):
    config = dict(DEFAULT_CONFIG)
    path = root / ".ai-project-index" / "config.json"
    if path.exists():
        user_config = json.loads(path.read_text(encoding="utf-8"))
        config.update(user_config)
    return config


def expand_patterns(root, patterns):
    paths = []
    for pattern in patterns:
        matches = sorted(root.glob(pattern))
        if matches:
            paths.extend(p.relative_to(root).as_posix() for p in matches if p.is_file())
        else:
            candidate = root / pattern
            if candidate.is_file():
                paths.append(pattern)
    return paths


def path_excluded(path, patterns):
    return any(fnmatch.fnmatch(path, pattern) for pattern in patterns)


def language_for(path):
    name = Path(path).name
    ext = Path(path).suffix.lower()
    if name == "SKILL.md":
        return "markdown"
    if ext == ".php":
        return "php"
    if ext in {".sh", ".bash", ".zsh"}:
        return "shell"
    if ext in {".yaml", ".yml"}:
        return "yaml"
    if ext == ".json":
        return "json"
    if ext == ".md":
        return "markdown"
    return ext.lstrip(".") or "unknown"


def category_for(path):
    if path.startswith("openspec/specs/"):
        return "accepted-spec"
    if path.startswith("openspec/changes/archive/"):
        return "archived-change"
    if path.startswith("openspec/changes/"):
        return "active-change"
    if path.startswith("skills/"):
        return "project-skill"
    if path.startswith(".codex/skills/"):
        return "workflow-skill"
    if path.startswith("docs/"):
        return "docs"
    if path.startswith("tests/"):
        return "tests"
    if Path(path).suffix.lower() in {".yaml", ".yml", ".json", ".toml"}:
        return "config"
    return "source"


def tags_for(path, text):
    tags = {language_for(path), category_for(path)}
    lower = path.lower() + "\n" + text[:4000].lower()
    for keyword, tag in [
        ("laravel-api-docs", "laravel-api-docs"),
        ("openapi", "openapi"),
        ("apidog", "apidog"),
        ("openspec", "openspec"),
        ("candidate", "candidate"),
        ("query parameter", "query-parameter"),
        ("queryparam", "query-parameter"),
        ("redoc", "redoc"),
        ("sync history", "sync-history"),
        ("conflict", "conflict"),
    ]:
        if keyword in lower:
            tags.add(tag)
    return sorted(t for t in tags if t)


def markdown_headings(text, limit=30):
    headings = []
    for line in text.splitlines():
        match = re.match(r"^(#{1,6})\s+(.+?)\s*$", line)
        if match:
            headings.append({"level": len(match.group(1)), "text": match.group(2)[:160]})
            if len(headings) >= limit:
                break
    return headings


def php_symbols(text, limit=80):
    symbols = []
    for kind, pattern in [
        ("class", r"\b(?:class|interface|trait|enum)\s+([A-Za-z_][A-Za-z0-9_]*)"),
        ("function", r"\bfunction\s+([A-Za-z_][A-Za-z0-9_]*)\s*\("),
    ]:
        for match in re.finditer(pattern, text):
            symbols.append({"kind": kind, "name": match.group(1)})
            if len(symbols) >= limit:
                return symbols
    return symbols


def shell_symbols(text, limit=80):
    symbols = []
    patterns = [
        r"^\s*function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\{",
        r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\{",
    ]
    for line in text.splitlines():
        for pattern in patterns:
            match = re.match(pattern, line)
            if match:
                symbols.append({"kind": "function", "name": match.group(1)})
                break
        if len(symbols) >= limit:
            break
    return symbols


def config_keys(text, limit=80):
    keys = []
    for line in text.splitlines():
        match = re.match(r"^\s*[\"']?([A-Za-z0-9_.-]+)[\"']?\s*[:=]", line)
        if match:
            keys.append(match.group(1))
        if len(keys) >= limit:
            break
    return keys


def keywords(text, limit=100):
    tokens = re.findall(r"[A-Za-z][A-Za-z0-9_-]{2,}|[\u4e00-\u9fff]{2,}", text.lower())
    noise = {"the", "and", "for", "with", "this", "that", "return", "function", "class"}
    counts = Counter(t for t in tokens if t not in noise)
    return [word for word, _ in counts.most_common(limit)]


def compact_excerpt(text, limit=600):
    normalized = re.sub(r"\s+", " ", text).strip()
    return normalized[:limit]


def analyze_file(root, rel):
    path = root / rel
    raw = path.read_bytes()
    text = raw.decode("utf-8", "ignore")
    lang = language_for(rel)
    entry = {
        "path": rel,
        "category": category_for(rel),
        "language": lang,
        "sizeBytes": len(raw),
        "lineCount": text.count("\n") + (0 if text.endswith("\n") or not text else 1),
        "sha1": hashlib.sha1(raw).hexdigest(),
        "tags": tags_for(rel, text),
        "headings": markdown_headings(text) if lang == "markdown" else [],
        "symbols": [],
        "keys": config_keys(text) if lang in {"yaml", "json", "toml"} else [],
        "keywords": keywords(rel + "\n" + text),
        "excerpt": compact_excerpt(text),
    }
    if lang == "php":
        entry["symbols"] = php_symbols(text)
    elif lang == "shell":
        entry["symbols"] = shell_symbols(text)
    return entry


def current_commit(root):
    raw = run_git(root, ["rev-parse", "HEAD"])
    return raw.decode("utf-8", "replace").strip() if raw else None


def main():
    parser = argparse.ArgumentParser(description="Generate compact AI project index.")
    parser.add_argument("root", nargs="?", default=".", help="Repository root")
    parser.add_argument("--output", default=".ai-project-index/index.json")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    config = load_config(root)
    paths = git_files(root) or walk_files(root)
    paths.extend(expand_patterns(root, config.get("includePaths", [])))
    exclude_paths = config.get("excludePaths", [])
    unique_paths = sorted(
        path for path in set(paths)
        if not path_excluded(path, exclude_paths) and (root / path).is_file()
    )

    files = []
    skipped = []
    for rel in unique_paths:
        path = root / rel
        if not path.is_file():
            skipped.append({"path": rel, "reason": "not a file"})
            continue
        if path.suffix.lower() not in TEXT_EXTENSIONS and path.name != "AGENTS.md":
            skipped.append({"path": rel, "reason": "unsupported extension"})
            continue
        try:
            files.append(analyze_file(root, rel))
        except Exception as exc:
            skipped.append({"path": rel, "reason": str(exc)})

    generated_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    index = {
        "version": "1.0.0",
        "project": {
            "name": root.name,
            "gitCommitHash": current_commit(root),
            "generatedAt": generated_at,
        },
        "scan": {
            "strategy": "git ls-files -co --exclude-standard plus configured includePaths",
            "fileCount": len(files),
            "skippedCount": len(skipped),
            "includePaths": config.get("includePaths", []),
            "excludePaths": exclude_paths,
            "expectedCoverage": config.get("expectedCoverage", []),
            "categories": dict(Counter(f["category"] for f in files)),
            "languages": dict(Counter(f["language"] for f in files)),
        },
        "files": files,
        "skipped": skipped,
    }

    output = root / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(index, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {output.relative_to(root)} ({len(files)} files, {len(skipped)} skipped)")


if __name__ == "__main__":
    main()
