#!/usr/bin/env python3
import argparse
import fnmatch
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


TOKEN_CHARS = 4


CASES = [
    {
        "id": "laravel-candidate-inference",
        "query": "infer-candidates php bin analyzer",
        "expected": [
            "skills/laravel-api-docs/bin/infer-candidates.php",
            "skills/laravel-api-docs/src/InferCandidates/Analyzer.php",
        ],
        "direct": [
            "skills/laravel-api-docs/SKILL.md",
            "skills/laravel-api-docs/bin/infer-candidates.php",
            "skills/laravel-api-docs/src/InferCandidates/*.php",
        ],
    },
    {
        "id": "openapi-generation",
        "query": "OpenAPI generator gen-openapi response analyzer",
        "expected": [
            "skills/laravel-api-docs/bin/gen-openapi.php",
            "skills/laravel-api-docs/src/OpenApiGenerator/OpenApiGenerator.php",
        ],
        "direct": [
            "skills/laravel-api-docs/SKILL.md",
            "skills/laravel-api-docs/bin/gen-openapi.php",
            "skills/laravel-api-docs/src/OpenApiGenerator/*.php",
        ],
    },
    {
        "id": "openspec-workflow-skills",
        "query": "openspec propose apply archive workflow skill",
        "expected": [
            ".codex/skills/openspec-propose/SKILL.md",
            ".codex/skills/openspec-apply-change/SKILL.md",
            ".codex/skills/openspec-archive-change/SKILL.md",
        ],
        "direct": [
            ".codex/skills/openspec-*/SKILL.md",
            "openspec/config.yaml",
            "AGENTS.md",
        ],
    },
    {
        "id": "accepted-specs",
        "query": "ai-project-index accepted spec requirements audit queryable index",
        "expected": [
            "openspec/specs/ai-project-index-skill/spec.md",
        ],
        "direct": [
            "openspec/specs/**/*.md",
        ],
    },
    {
        "id": "docs",
        "query": "install skills publish docs repo based install",
        "expected": [
            "docs/install-skills.md",
            "docs/publish-skills.md",
        ],
        "direct": [
            "docs/*.md",
        ],
    },
    {
        "id": "tests",
        "query": "query parameter generator tests",
        "expected": [
            "tests/laravel_api_docs_query_parameters_test.php",
        ],
        "direct": [
            "tests/*.php",
        ],
    },
    {
        "id": "generated-docs-default-excluded",
        "query": "Generated Project Map business logic draft",
        "expected_absent": [
            "docs/generated/**",
        ],
        "direct": [
            "docs/generated/*.md",
        ],
    },
    {
        "id": "archived-change-default-excluded",
        "query": "evaluate understand anything docs layer",
        "expected_absent": [
            "openspec/changes/archive/**",
        ],
        "direct": [
            "openspec/changes/archive/**/*.md",
        ],
    },
    {
        "id": "archived-change-explicit-inclusion",
        "query": "evaluate understand anything docs layer",
        "include_archive": True,
        "expected": [
            "openspec/changes/archive/2026-06-02-evaluate-understand-anything-as-docs-layer/proposal.md",
            "openspec/changes/archive/2026-06-02-evaluate-understand-anything-as-docs-layer/tasks.md",
        ],
        "direct": [
            "openspec/changes/archive/2026-06-02-evaluate-understand-anything-as-docs-layer/*.md",
        ],
    },
    {
        "id": "ai-project-index-self-explicit-inclusion",
        "query": "refresh index evaluation audit rules",
        "include_self": True,
        "expected": [
            "skills/ai-project-index/SKILL.md",
            "skills/ai-project-index/scripts/audit-index.py",
        ],
        "expected_absent_without_flags": [
            "skills/ai-project-index/**",
        ],
        "direct": [
            "skills/ai-project-index/SKILL.md",
            "skills/ai-project-index/scripts/*.py",
        ],
    },
]


def estimate_tokens(text):
    return (len(text) + TOKEN_CHARS - 1) // TOKEN_CHARS


def read_text(path):
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return ""


def expand_patterns(root, patterns):
    paths = []
    for pattern in patterns:
        matches = sorted(root.glob(pattern))
        paths.extend(p for p in matches if p.is_file())
        candidate = root / pattern
        if candidate.is_file() and candidate not in paths:
            paths.append(candidate)
    return sorted(set(paths))


def run_query(root, script, index, case, limit):
    cmd = [
        sys.executable,
        str(script),
        case["query"],
        "--index",
        index,
        "--limit",
        str(limit),
        "--json",
    ]
    if case.get("include_archive"):
        cmd.append("--include-archive")
    if case.get("include_changes"):
        cmd.append("--include-changes")
    if case.get("include_self"):
        cmd.append("--include-self")
    result = subprocess.run(cmd, cwd=root, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    output = result.stdout.decode("utf-8")
    return output, json.loads(output)


def match_any(path, patterns):
    return any(fnmatch.fnmatch(path, pattern) for pattern in patterns)


def evaluate_case(root, script, index, case, limit, target_read_limit):
    output_text, query_data = run_query(root, script, index, case, limit)
    result_paths = [item["path"] for item in query_data.get("results", [])]
    result_path_set = set(result_paths)

    expected = case.get("expected", [])
    expected_absent = case.get("expected_absent", [])
    expected_absent_without_flags = case.get("expected_absent_without_flags", [])

    matched_expected = [pattern for pattern in expected if match_any_pattern_set(result_path_set, pattern)]
    missed_expected = [pattern for pattern in expected if pattern not in matched_expected]
    unexpected_present = [path for path in result_paths if match_any(path, expected_absent)]

    default_unexpected_present = []
    if expected_absent_without_flags:
        default_case = dict(case)
        default_case.pop("include_archive", None)
        default_case.pop("include_changes", None)
        default_case.pop("include_self", None)
        _, default_data = run_query(root, script, index, default_case, limit)
        default_paths = [item["path"] for item in default_data.get("results", [])]
        default_unexpected_present = [
            path for path in default_paths if match_any(path, expected_absent_without_flags)
        ]

    direct_paths = expand_patterns(root, case.get("direct", []))
    direct_chars = sum(len(read_text(path)) for path in direct_paths)
    direct_tokens = estimate_tokens(case["query"]) + estimate_tokens("".join(read_text(path) for path in direct_paths))

    target_paths = [root / path for path in result_paths[:target_read_limit] if (root / path).is_file()]
    target_chars = sum(len(read_text(path)) for path in target_paths)
    index_tokens = estimate_tokens(case["query"]) + estimate_tokens(output_text) + estimate_tokens(
        "".join(read_text(path) for path in target_paths)
    )

    passed = not missed_expected and not unexpected_present and not default_unexpected_present
    savings = direct_tokens - index_tokens
    savings_percent = round((savings / direct_tokens) * 100, 1) if direct_tokens else 0.0

    return {
        "id": case["id"],
        "query": case["query"],
        "passed": passed,
        "flags": {
            "includeArchive": bool(case.get("include_archive")),
            "includeChanges": bool(case.get("include_changes")),
            "includeSelf": bool(case.get("include_self")),
        },
        "expected": expected,
        "matchedExpected": matched_expected,
        "missedExpected": missed_expected,
        "expectedAbsent": expected_absent,
        "unexpectedPresent": unexpected_present,
        "defaultUnexpectedPresent": default_unexpected_present,
        "resultPaths": result_paths,
        "directInspection": {
            "patterns": case.get("direct", []),
            "pathCount": len(direct_paths),
            "charCount": direct_chars,
            "approxTokens": direct_tokens,
        },
        "indexAssistedInspection": {
            "queryResultPathCount": len(result_paths),
            "targetReadLimit": target_read_limit,
            "targetReadPathCount": len(target_paths),
            "targetReadCharCount": target_chars,
            "approxTokens": index_tokens,
        },
        "approxTokenSavings": savings,
        "approxTokenSavingsPercent": savings_percent,
    }


def match_any_pattern_set(paths, pattern):
    return any(fnmatch.fnmatch(path, pattern) for path in paths)


def markdown_report(data):
    lines = [
        "# AI Project Index Evaluation",
        "",
        "This report is generated. Token counts are approximate estimates for relative comparison only.",
        "",
        f"- Generated at: `{data['generatedAt']}`",
        f"- Cases: `{data['summary']['caseCount']}`",
        f"- Passed: `{data['summary']['passedCount']}`",
        f"- Failed: `{data['summary']['failedCount']}`",
        f"- Approx direct tokens: `{data['summary']['directApproxTokens']}`",
        f"- Approx index-assisted tokens: `{data['summary']['indexAssistedApproxTokens']}`",
        f"- Approx savings: `{data['summary']['approxTokenSavings']}` ({data['summary']['approxTokenSavingsPercent']}%)",
        "",
    ]
    for case in data["cases"]:
        status = "PASS" if case["passed"] else "FAIL"
        lines.extend([
            f"## {case['id']} - {status}",
            "",
            f"- Query: `{case['query']}`",
            f"- Direct approx tokens: `{case['directInspection']['approxTokens']}`",
            f"- Index-assisted approx tokens: `{case['indexAssistedInspection']['approxTokens']}`",
            f"- Approx savings: `{case['approxTokenSavings']}` ({case['approxTokenSavingsPercent']}%)",
            f"- Matched expected: {', '.join('`' + p + '`' for p in case['matchedExpected']) or '`none`'}",
            f"- Missed expected: {', '.join('`' + p + '`' for p in case['missedExpected']) or '`none`'}",
            f"- Unexpected present: {', '.join('`' + p + '`' for p in case['unexpectedPresent']) or '`none`'}",
            "",
            "Top result paths:",
            "",
        ])
        for path in case["resultPaths"][:8]:
            lines.append(f"- `{path}`")
        lines.append("")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Evaluate AI project index discovery quality and approximate token savings.")
    parser.add_argument("root", nargs="?", default=".", help="Repository root")
    parser.add_argument("--index", default=".ai-project-index/index.json")
    parser.add_argument("--output", default=".ai-project-index/evaluation.json")
    parser.add_argument("--markdown-output", default=".ai-project-index/evaluation.md")
    parser.add_argument("--limit", type=int, default=12)
    parser.add_argument("--target-read-limit", type=int, default=5)
    args = parser.parse_args()

    root = Path(args.root).resolve()
    script = Path(__file__).resolve().parent / "query-index.py"
    cases = [
        evaluate_case(root, script, args.index, case, args.limit, args.target_read_limit)
        for case in CASES
    ]
    direct_tokens = sum(case["directInspection"]["approxTokens"] for case in cases)
    index_tokens = sum(case["indexAssistedInspection"]["approxTokens"] for case in cases)
    savings = direct_tokens - index_tokens
    savings_percent = round((savings / direct_tokens) * 100, 1) if direct_tokens else 0.0
    data = {
        "version": "1.0.0",
        "generatedAt": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "tokenEstimate": {
            "method": f"ceil(character_count / {TOKEN_CHARS})",
            "note": "Approximate relative estimate, not model tokenizer billing output.",
        },
        "summary": {
            "caseCount": len(cases),
            "passedCount": sum(1 for case in cases if case["passed"]),
            "failedCount": sum(1 for case in cases if not case["passed"]),
            "directApproxTokens": direct_tokens,
            "indexAssistedApproxTokens": index_tokens,
            "approxTokenSavings": savings,
            "approxTokenSavingsPercent": savings_percent,
        },
        "cases": cases,
    }

    output = root / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    markdown_output = root / args.markdown_output
    markdown_output.parent.mkdir(parents=True, exist_ok=True)
    markdown_output.write_text(markdown_report(data), encoding="utf-8")

    print(f"Evaluation status: {data['summary']['passedCount']}/{data['summary']['caseCount']} passed")
    print(json.dumps(data["summary"], ensure_ascii=False, indent=2))
    if data["summary"]["failedCount"]:
        print("Failed cases:")
        for case in cases:
            if not case["passed"]:
                print(f"  - {case['id']}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
