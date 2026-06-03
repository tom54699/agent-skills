## Context

The repository now has `skills/ai-project-index/`, which can generate a compact `.ai-project-index/index.json`, query it, audit expected coverage, and generate draft docs. The index is useful as AI routing context, but it is only reliable when it is fresh and when agents know how to use it without treating it as source of truth.

The current workflow is manual: run generation, optionally query, optionally audit. There is no explicit post-change refresh habit, no repeatable token/discovery evaluation, and no documented rule for when AI should query the index versus reading source files directly.

## Goals / Non-Goals

**Goals:**

- Define a low-friction refresh workflow for updating `.ai-project-index` after code, spec, docs, or test changes.
- Add a repeatable evaluation harness or documented test matrix for comparing index-assisted discovery against direct repository reading.
- Strengthen audit confidence for stale commits, missing indexed files, missing expected coverage, and file moves/deletions.
- Document AI usage rules that keep the index as routing context and require verification against source/spec/docs/tests.
- Keep generated outputs local-regenerate unless a future change decides otherwise.

**Non-Goals:**

- Do not add a mandatory git hook in this change.
- Do not commit generated `.ai-project-index/index.json` as a required source artifact.
- Do not add a final workflow skill before the refresh and evaluation process is validated.
- Do not replace source reading, tests, accepted specs, or reviewed docs with generated index content.

## Decisions

### Decision: Start with manual refresh plus audit

Add a documented `refresh` flow that runs generation and audit in sequence, either as a new script or as explicit commands in `SKILL.md` and docs.

Alternative considered: install a git hook immediately. That is premature because the desired behavior around ignored files, local-only outputs, and when to refresh is still being evaluated.

### Decision: Evaluate discovery instead of only file size

The evaluation should compare realistic questions across source, OpenSpec, docs, and tests. Each case should record:

- direct-read candidate paths and approximate token cost
- index-query candidate paths and approximate token cost
- whether the index found the expected source-of-truth files
- what files still needed direct reading after query

Alternative considered: measure only `.ai-project-index/index.json` size. Size is useful but does not prove whether the index actually improves routing.

### Decision: Keep approximate token measurement local and deterministic

Use a simple repeatable estimator, such as character count divided by a fixed ratio, for relative comparison. The goal is not billing precision; it is to compare "read everything likely relevant" versus "query index, then read targeted files" consistently.

Alternative considered: depend on an external tokenizer package. That adds dependency and network friction before the workflow has proven value.

### Decision: Audit must fail loudly on stale or structurally incomplete output

`audit-index.py` should report warning status when the index commit differs from the current commit, indexed paths no longer exist, expected coverage is missing, or the index has no files. The user and AI can then decide to regenerate before using it.

Alternative considered: silently allow stale index use and document caveats. That makes it too easy for AI to route from outdated context.

### Decision: AI usage rules belong in the skill and docs

The skill should explicitly tell agents to query first for broad discovery, then read returned source-of-truth files. It should also say when not to rely on the index: behavior verification, exact API contracts, security-sensitive changes, and recently edited files when audit is stale.

Alternative considered: leave usage to agent judgment. The previous evaluation showed that token control depends on clear rules.

## Risks / Trade-offs

- [Risk] Token estimates may not match a specific model tokenizer exactly → Use estimates only for relative comparison and label them as approximate.
- [Risk] Manual refresh can still be forgotten → Make audit stale detection visible and document when refresh is expected.
- [Risk] Evaluation cases may overfit this small repo → Include cases across skill source, OpenSpec specs, docs, tests, generated docs, and archived changes.
- [Risk] Index query may miss behavior hidden in implementation details → Require final verification against source files and tests.
- [Risk] Adding sync automation too early may annoy normal commits → Keep hooks and pre-commit integration as a later decision after manual workflow validation.
