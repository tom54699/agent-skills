## Why

`.ai-project-index` 已能產生輕量索引，但目前還缺少明確的持續同步流程、查詢品質驗證方式，以及 AI 何時該用索引、何時必須回到 source of truth 的規則。
這會讓索引在 code 變更後容易 stale，也難以客觀判斷它是否真的省 token、是否足夠可靠。

## What Changes

- Add a documented refresh workflow for keeping `.ai-project-index` synchronized after repository changes.
- Add repeatable evaluation cases that compare index-assisted discovery against direct source inspection.
- Add audit coverage for stale or incomplete indexes after file moves, deletions, and expected path changes.
- Document AI usage rules for treating `.ai-project-index` as a routing aid instead of source of truth.
- Keep generated `.ai-project-index` artifacts local-regenerate by default.
- Do not add a final workflow skill or commit hook until the workflow is validated.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `ai-project-index-skill`: Extend requirements for synchronization, evaluation, audit confidence, and AI usage guidance.

## Impact

- Affected skill: `skills/ai-project-index/`
- Affected local artifacts: `.ai-project-index/index.json`, `.ai-project-index/audit.json`
- Affected docs: `docs/` guidance for generated drafts and AI usage rules
- Affected specs: `openspec/specs/ai-project-index-skill/spec.md`
- No runtime production system impact.
