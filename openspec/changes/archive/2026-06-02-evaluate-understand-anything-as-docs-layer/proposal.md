## Why

The project currently relies on manually maintained `AGENTS.md`, `CLAUDE.md`, and `docs/` reading instructions to help AI agents understand the repository before feature work. We need to evaluate whether Understand Anything can become the primary current-system understanding layer, reducing hand-written navigation docs while preserving OpenSpec as the change-specification workflow.

## What Changes

- Introduce an evaluation workflow for running Understand Anything on this repository.
- Compare Understand Anything output against existing repository knowledge:
  - `skills/.curated/laravel-api-docs`
  - `.codex/skills/openspec-*`
  - `openspec/specs`
  - `docs/`
  - `tests/`
- Decide which documentation categories can be replaced by generated understanding artifacts.
- Decide which documentation categories must remain manually maintained.
- Define how Understand Anything and OpenSpec should coordinate during future feature development.
- Do not create the final workflow skill yet; use this evaluation to inform that design.

## Capabilities

### New Capabilities

- `project-understanding-layer`: Defines how the project evaluates and uses Understand Anything as the current-system understanding layer alongside OpenSpec.

### Modified Capabilities

- None.

## Impact

- May add `.understand-anything/` artifacts after evaluation, subject to review.
- May update `.gitignore` once generated artifact policy is decided.
- May update repository documentation to explain the Understand Anything / OpenSpec responsibility boundary.
- No production code, Laravel API docs analyzer behavior, or Apidog sync behavior should change in this evaluation.
