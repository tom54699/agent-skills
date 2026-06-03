## Why

The current `skills/.curated/` and `skills/.experimental/` split adds path noise without helping day-to-day use. Users and agents should be able to find skills directly under `skills/<skill-name>/` without first deciding whether a skill is curated or experimental.

## What Changes

- Flatten repository skill locations to direct paths under `skills/<skill-name>/`.
- Move existing project skills out of `.curated` and `.experimental` folders.
- Update skill repository layout requirements so curated/experimental directory classification is no longer required.
- Update `ai-project-index-skill` requirements so the skill lives at `skills/ai-project-index/`.
- Update repository guidance and docs that reference the old `.curated` or `.experimental` paths.
- Keep behavioral implementation of individual skills unchanged in this change.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `skill-repo-layout`: Replace curated/experimental directory separation with direct `skills/<skill-name>/` layout.
- `ai-project-index-skill`: Change required skill location from `skills/.experimental/ai-project-index/` to `skills/ai-project-index/`.

## Impact

- Moves `skills/.curated/laravel-api-docs/` to `skills/laravel-api-docs/`.
- Moves `skills/.experimental/ai-project-index/` to `skills/ai-project-index/`.
- Updates AGENTS/CLAUDE/docs references that currently point to `.curated` or `.experimental` paths.
- Updates OpenSpec accepted specs for skill layout and AI project index skill.
- Does not change Laravel API docs runtime behavior.
- Does not implement AI project index sync/query improvements in this change.
