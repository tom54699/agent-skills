## MODIFIED Requirements

### Requirement: AI Project Index Skill
The repository SHALL provide an `ai-project-index` skill that generates a compact AI-facing project index without requiring a dashboard or domain graph.

#### Scenario: Skill exists in active skills
- **WHEN** a user looks for the AI project index skill
- **THEN** the skill MUST exist under `skills/ai-project-index/`
- **AND** the skill MUST include a `SKILL.md` entrypoint

### Requirement: Index Audit
The skill SHALL provide an audit command that reports whether the generated index is safe to use as AI routing context.

#### Scenario: Expected coverage audit
- **WHEN** the audit command runs
- **THEN** it MUST verify expected coverage for `skills/laravel-api-docs/`, `openspec/specs/`, `docs/`, `tests/`, OpenSpec workflow skills, and project guidance files
- **AND** it MUST report missing expected paths instead of silently accepting incomplete coverage

#### Scenario: Integrity audit
- **WHEN** the audit command runs
- **THEN** it MUST report duplicate indexed paths, missing indexed files, empty index output, and stale index metadata when detectable
