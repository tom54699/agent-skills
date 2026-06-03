## Context

The previous Understand Anything evaluation proved that a structural index can help AI agents find relevant source/spec/test files with less exploration cost. It also showed several mismatches for this repository:

- The upstream tool produces dashboard, domain graph, intermediate, and frontend-oriented artifacts that are not needed for AI-only indexing.
- The generated structural graph is useful as an index, but it is not a source of truth.
- Ignored local workflow files such as `.codex/skills/openspec-*` and `AGENTS.md` may be missed by default scanning.
- The project needs a deterministic, reviewable, repo-native skill before designing a larger OpenSpec workflow skill.

## Goals / Non-Goals

**Goals:**

- Add an experimental skill at `skills/.experimental/ai-project-index/`.
- Generate a compact `.ai-project-index/index.json` suitable for AI query and routing.
- Provide a query command that returns ranked candidate paths and small node summaries.
- Provide an audit command that reports missing expected paths and basic index integrity issues.
- Allow local-only include paths without requiring generated output to be committed.
- Optionally generate `docs/generated/project-map.md` and `docs/generated/business-logic-draft.md` as reviewed drafts.
- Run the new skill against this repository and inspect whether its output matches expected coverage.

**Non-Goals:**

- Do not build or fork a dashboard.
- Do not generate a domain graph renderer.
- Do not use generated docs as source of truth without review.
- Do not add automatic git hooks in this change.
- Do not change Laravel API docs sync runtime behavior.

## Decisions

1. Create a new experimental skill rather than modifying `laravel-api-docs` or vendoring the full Understand Anything plugin.
   - Rationale: the new behavior is repository understanding infrastructure, not Laravel API docs business logic.
   - Alternative considered: copy the full upstream skill and delete unused parts.
   - Rejected because it would inherit dashboard/domain complexity and external maintenance cost.

2. Store generated output under `.ai-project-index/`.
   - Rationale: avoids confusion with upstream `.understand-anything/` artifacts and makes this project-specific index policy explicit.
   - Commit policy: generated outputs are local regenerate artifacts by default.

3. Use deterministic extraction for the first version.
   - Extract file metadata, Markdown headings, PHP class/function names, shell function names, YAML/JSON keys, path-derived tags, and content keywords.
   - Avoid LLM-generated summaries in the first version to keep output predictable and auditable.

4. Keep query output small and path-focused.
   - The query script returns ranked paths, matched fields, and short snippets.
   - Agents must use the index to choose source files, then read original files for truth.

5. Add an audit report before treating the index as useful.
   - Audit checks expected coverage for curated skill, accepted specs, docs, tests, OpenSpec workflow skills, and project guidance files.
   - Audit also checks duplicate paths, missing files, empty index, and stale metadata.

6. Generate docs only as drafts.
   - `docs/generated/project-map.md` and `docs/generated/business-logic-draft.md` may be created, but they must be labelled as generated drafts.
   - Human-maintained docs, accepted OpenSpec specs, and tests remain source of truth.

## Risks / Trade-offs

- Generated index may omit semantic relationships -> mitigate with audit coverage and source-of-truth verification rules.
- Deterministic extraction may be shallower than LLM summaries -> acceptable for first version because the goal is routing, not authoritative explanation.
- Local-only includes can accidentally index private files -> make include configuration explicit and keep generated artifacts ignored.
- Query ranking may be noisy -> keep scoring simple and inspect results from this repo before promoting the skill.
- Generated docs may be mistaken for approved docs -> label drafts clearly and keep them under `docs/generated/`.
