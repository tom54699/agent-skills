# ai-project-index-skill Specification

## Purpose
定義本專案的 `ai-project-index` skill：產生、查詢、稽核一份給 AI 使用的輕量專案索引，作為 source/spec/docs/tests 的 routing aid，而不是 source of truth。

## Requirements
### Requirement: AI Project Index Skill
The repository SHALL provide an `ai-project-index` skill that generates a compact AI-facing project index without requiring a dashboard or domain graph.

#### Scenario: Skill exists in active skills
- **WHEN** a user looks for the AI project index skill
- **THEN** the skill MUST exist under `skills/ai-project-index/`
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

### Requirement: Generated Documentation Drafts
The skill MAY generate documentation drafts from the compact index, but generated drafts SHALL remain local-regenerate output and SHALL NOT become source of truth without review.

#### Scenario: Generate project map draft
- **WHEN** documentation draft generation is requested
- **THEN** the skill MAY write `docs/generated/project-map.md`
- **AND** the file MUST be labelled as a generated draft requiring review
- **AND** the file MUST NOT be committed by default

#### Scenario: Generate business logic draft
- **WHEN** business logic draft generation is requested
- **THEN** the skill MAY write `docs/generated/business-logic-draft.md`
- **AND** the file MUST be labelled as a generated draft requiring review
- **AND** the file MUST NOT be committed by default

### Requirement: Index Refresh Workflow
The skill SHALL define a repeatable refresh workflow for keeping `.ai-project-index` synchronized with repository changes.

#### Scenario: Refresh after source-of-truth changes
- **WHEN** project source, accepted OpenSpec specs, docs, tests, project guidance, or skill files change
- **THEN** the refresh workflow MUST regenerate `.ai-project-index/index.json`
- **AND** it MUST run the audit command before the index is treated as reliable routing context

#### Scenario: Generated artifacts remain local
- **WHEN** the refresh workflow updates `.ai-project-index` artifacts
- **THEN** those artifacts MUST remain local-regenerate outputs unless a later OpenSpec change explicitly changes the commit policy
- **AND** the workflow MUST NOT require committing generated `.ai-project-index/index.json`

#### Scenario: Refresh guidance is visible to agents
- **WHEN** an AI agent reads the `ai-project-index` skill instructions
- **THEN** the skill MUST describe when to refresh, when to audit, and when to avoid using a stale index

### Requirement: Index-Assisted Discovery Evaluation
The skill SHALL include a repeatable evaluation process for comparing index-assisted discovery against direct repository inspection.

#### Scenario: Evaluate realistic project questions
- **WHEN** the evaluation process runs
- **THEN** it MUST include cases covering project skill source, OpenSpec workflow/specs, docs, tests, generated docs, and archived changes where relevant
- **AND** each case MUST define the expected source-of-truth paths or path patterns

#### Scenario: Compare approximate token cost
- **WHEN** a discovery case is evaluated
- **THEN** the process MUST record an approximate token cost for direct repository inspection
- **AND** it MUST record an approximate token cost for index query plus targeted source reading
- **AND** the result MUST label token counts as approximate estimates

#### Scenario: Record routing quality
- **WHEN** a discovery case is evaluated
- **THEN** the process MUST record whether index results included the expected source-of-truth paths
- **AND** it MUST record any missed paths or cases requiring direct source fallback

### Requirement: AI Index Usage Rules
The skill SHALL document how AI agents use `.ai-project-index` as routing context without replacing source-of-truth reading.

#### Scenario: Broad discovery uses query first
- **WHEN** an AI agent needs to discover likely relevant files for a broad project question
- **THEN** the agent MUST prefer a targeted index query over loading the full index into model context
- **AND** the agent MUST read the returned source, spec, docs, or test files before making behavior claims

#### Scenario: Source of truth remains authoritative
- **WHEN** an AI agent needs exact behavior, API contract, security-sensitive details, or implementation-specific reasoning
- **THEN** the agent MUST verify against source files, accepted OpenSpec specs, reviewed docs, or tests
- **AND** the agent MUST NOT treat generated index excerpts or generated docs as authoritative

#### Scenario: Stale audit blocks index reliance
- **WHEN** the audit status is warning because the index is stale, incomplete, or structurally invalid
- **THEN** the agent MUST refresh and re-audit the index before relying on it for routing
- **AND** the agent MAY still read source files directly without using the index
