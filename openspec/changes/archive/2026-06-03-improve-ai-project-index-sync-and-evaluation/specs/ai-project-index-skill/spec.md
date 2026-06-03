## ADDED Requirements

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
