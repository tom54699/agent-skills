## Why

`docs/generated/*` 是由 `ai-project-index` 產生的草稿文件，尚未經人工 review 成正式文件。
若直接提交，容易讓 generated draft 被誤認為 source of truth。

## What Changes

- Treat `docs/generated/*` as local-regenerate output by default.
- Ignore generated draft docs in git unless a future OpenSpec change promotes reviewed content into formal docs.
- Clarify the `ai-project-index-skill` generated documentation requirement.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `ai-project-index-skill`: Generated documentation drafts remain local-regenerate and are not committed by default.

## Impact

- Affected files: `.gitignore`, `openspec/specs/ai-project-index-skill/spec.md`
- Affected local artifacts: `docs/generated/project-map.md`, `docs/generated/business-logic-draft.md`
- No runtime behavior impact.
