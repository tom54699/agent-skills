## ADDED Requirements

### Requirement: Experimental AI Project Index Skill
The repository SHALL provide an experimental `ai-project-index` skill that generates a compact AI-facing project index without requiring a dashboard or domain graph.

#### Scenario: Skill exists in experimental skills
- **WHEN** a user looks for the AI project index skill
- **THEN** the skill MUST exist under `skills/.experimental/ai-project-index/`
- **AND** the skill MUST include a `SKILL.md` entrypoint

### Requirement: Compact Index Generation
The skill SHALL generate a compact project index that helps AI agents find relevant source files, specs, docs, and tests without reading the full repository.

#### Scenario: Generate index for current repository
- **WHEN** the skill is run against the repository root
- **THEN** it MUST write `.ai-project-index/index.json`
- **AND** the index MUST include project metadata, analyzed file entries, extracted symbols/headings, tags, and generation metadata

#### Scenario: Generated output remains local by default
- **WHEN** `.ai-project-index/` output is generated
- **THEN** generated index, audit, and query artifacts MUST be treated as local-regenerate artifacts unless a future change explicitly decides otherwise

### Requirement: Queryable Index
The skill SHALL provide a query command that returns small ranked results from the generated index.

#### Scenario: Query by behavior keyword
- **WHEN** a user or AI queries the index with a behavior keyword
- **THEN** the command MUST return ranked candidate paths with matched fields and short summaries
- **AND** the command MUST NOT require loading the full index into model context

#### Scenario: Query excludes archived changes by default
- **WHEN** query results include archived OpenSpec changes
- **THEN** archived changes MUST be excluded by default
- **AND** the command MAY provide an option to include archived changes

### Requirement: Index Audit
The skill SHALL provide an audit command that reports whether the generated index is safe to use as AI routing context.

#### Scenario: Expected coverage audit
- **WHEN** the audit command runs
- **THEN** it MUST verify expected coverage for `skills/.curated/laravel-api-docs/`, `openspec/specs/`, `docs/`, `tests/`, OpenSpec workflow skills, and project guidance files
- **AND** it MUST report missing expected paths instead of silently accepting incomplete coverage

#### Scenario: Integrity audit
- **WHEN** the audit command runs
- **THEN** it MUST report duplicate indexed paths, missing indexed files, empty index output, and stale index metadata when detectable

### Requirement: Generated Documentation Drafts
The skill MAY generate documentation drafts from the compact index, but generated drafts SHALL NOT become source of truth without review.

#### Scenario: Generate project map draft
- **WHEN** documentation draft generation is requested
- **THEN** the skill MAY write `docs/generated/project-map.md`
- **AND** the file MUST be labelled as a generated draft requiring review

#### Scenario: Generate business logic draft
- **WHEN** business logic draft generation is requested
- **THEN** the skill MAY write `docs/generated/business-logic-draft.md`
- **AND** the file MUST be labelled as a generated draft requiring review
