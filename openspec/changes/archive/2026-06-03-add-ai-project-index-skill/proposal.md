## Why

The Understand Anything evaluation showed that a structural index can reduce AI exploration cost, but the full upstream tool carries dashboard/domain artifacts the project does not need and can miss ignored local workflow files. We need a smaller repo-native skill that produces a compact AI-facing project index, supports targeted querying, and audits whether the index is safe to use before agents rely on it.

## What Changes

- Add an experimental `ai-project-index` skill under `skills/.experimental/`.
- Add deterministic scripts for scanning the repository and producing a compact AI index.
- Add a query script that returns ranked file/path candidates without loading the full index into context.
- Add an audit script that verifies expected coverage and graph/index integrity.
- Allow local-only include paths so AI workflow files can be indexed without committing generated artifacts.
- Optionally generate reviewed-draft documentation under `docs/generated/` for project maps and business-flow notes.
- Run the new skill against this repository and evaluate whether the generated index matches the expected source/spec/test/docs coverage.
- Do not add a frontend dashboard, domain graph renderer, or automatic commit hook in this change.

## Capabilities

### New Capabilities
- `ai-project-index-skill`: Defines the experimental skill for generating, querying, auditing, and optionally documenting a compact AI project index.

### Modified Capabilities
- `project-understanding-layer`: Clarifies that the project may use a lightweight AI project index as the preferred AI-facing current-system index while preserving OpenSpec and source files as source of truth.

## Impact

- Adds files under `skills/.experimental/ai-project-index/`.
- May add local generated output under `.ai-project-index/`, which should be ignored by version control except intentional configuration files.
- May add or update documentation under `docs/` for usage and artifact policy.
- Updates OpenSpec specs for the AI index capability and project understanding workflow.
- Does not change Laravel API docs runtime behavior or Apidog sync behavior.
