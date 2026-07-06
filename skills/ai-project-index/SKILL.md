---
name: ai-project-index
description: Generate, query, audit, and optionally document a compact AI-facing project index for this repository. Use when an agent needs repository structure, relevant source/spec/test/doc paths, or a low-token discovery index before reading source-of-truth files.
metadata:
  version: "1.0.0"
---

# AI Project Index

Use this skill to create a compact local index that helps AI agents find relevant repository context without reading the whole codebase.

The index is a routing aid, not source of truth. Always verify behavior claims against source files, accepted OpenSpec specs, docs, or tests.

## Commands

Run from the repository root.

```bash
python3 skills/ai-project-index/scripts/refresh-index.py
python3 skills/ai-project-index/scripts/generate-index.py
python3 skills/ai-project-index/scripts/query-index.py "query parameter"
python3 skills/ai-project-index/scripts/audit-index.py
python3 skills/ai-project-index/scripts/evaluate-index.py
python3 skills/ai-project-index/scripts/generate-docs.py
```

## Outputs

- `.ai-project-index/index.json` - compact generated index for AI query.
- `.ai-project-index/audit.json` - coverage and integrity report.
- `.ai-project-index/evaluation.json` - generated discovery and approximate token comparison report.
- `.ai-project-index/evaluation.md` - readable generated evaluation summary.
- `docs/generated/project-map.md` - generated draft project map.
- `docs/generated/business-logic-draft.md` - generated draft business flow notes.

Generated artifacts are local-regenerate outputs unless a future OpenSpec change decides otherwise.
Generated docs are excluded from the default index so draft output does not feed back into later query rankings.

## Refresh Rules

Run refresh after changes to source files, accepted OpenSpec specs, active OpenSpec changes, docs, tests, project guidance files, or skill files.

```bash
python3 skills/ai-project-index/scripts/refresh-index.py
```

Refresh runs index generation and audit in sequence. If audit status is `warning`, do not rely on the index for routing until it is refreshed and re-audited, unless you decide to bypass the index and read source files directly.

## Workflow

1. Generate or refresh the index.
2. Query the index for candidate paths.
3. Read the original files returned by the query.
4. Run audit before treating the index as reliable routing context.
5. Use generated docs only as reviewed drafts.

Do not load the full index into model context when a targeted query is enough.

## AI Usage Rules

- Use targeted queries for broad discovery before reading many files.
- Treat the index as routing context only.
- Verify behavior claims against source files, accepted OpenSpec specs, reviewed docs, or tests.
- Do not treat generated index excerpts or generated docs as source of truth.
- Prefer direct source reading for exact behavior, API contracts, security-sensitive reasoning, or recently edited files when audit is stale.
- Use `--include-archive` only when archived OpenSpec history is intentionally relevant.
- Use `--include-self` only when evaluating or modifying this skill.

## Evaluation

Run discovery and approximate token comparison cases from the repository root.

```bash
python3 skills/ai-project-index/scripts/evaluate-index.py
```

The evaluation output is generated under `.ai-project-index/`. Token counts are approximate estimates for comparing discovery strategies, not model billing output.
