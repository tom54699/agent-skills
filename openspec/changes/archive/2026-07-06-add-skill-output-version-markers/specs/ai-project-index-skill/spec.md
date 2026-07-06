## MODIFIED Requirements

### Requirement: Index Audit
The skill SHALL provide an audit command that reports whether the generated index is safe to use as AI routing context.

#### Scenario: Expected coverage audit
- **WHEN** the audit command runs
- **THEN** it MUST verify expected coverage for `skills/laravel-api-docs/`, `openspec/specs/`, `docs/`, `tests/`, OpenSpec workflow skills, and project guidance files
- **AND** it MUST report missing expected paths instead of silently accepting incomplete coverage

#### Scenario: Integrity audit
- **WHEN** the audit command runs
- **THEN** it MUST report duplicate indexed paths, missing indexed files, empty index output, and stale index metadata when detectable

#### Scenario: File move and deletion audit
- **WHEN** indexed paths no longer exist in the repository
- **THEN** the audit command MUST report those paths as missing indexed files
- **AND** the audit status MUST be warning

#### Scenario: Commit freshness audit
- **WHEN** the generated index records a git commit that differs from the current repository commit
- **THEN** the audit command MUST report the index as stale
- **AND** the audit status MUST be warning

#### Scenario: Index schema version audit
- **WHEN** the audit command reads an `index.json` whose `version` field does not match the auditor's expected schema version
- **THEN** the audit command MUST report the audit status as warning with a `version_mismatch` reason
- **AND** it MUST NOT silently produce an `ok` status for a schema version it does not recognize

## ADDED Requirements

### Requirement: Skill Version Metadata
The skill SHALL carry a version identifier to support future compatibility checks.

#### Scenario: SKILL.md declares a version
- **WHEN** the skill's frontmatter is inspected
- **THEN** it MUST include a `metadata.version` field
