# laravel-api-docs-bootstrap-initialization Specification

## Purpose
TBD - created by archiving change refine-laravel-api-docs-initialization-flow. Update Purpose after archive.
## Requirements
### Requirement: Skill SHALL require initialization baseline decision when no success history exists
When no successful sync history is available, the skill MUST run an initialization decision step before candidate inference.

#### Scenario: No success history found
- **WHEN** `docs/api-docs/history/apidog-sync-history.jsonl` has no `status=success` record
- **THEN** the skill prompts for baseline source selection: local OpenAPI, Apidog export, or no baseline

### Requirement: Skill SHALL support commit-bounded initialization range
If baseline is not available from local OpenAPI or Apidog export, the skill MUST require user-provided `from_commit` and use it as initialization range start.

#### Scenario: User chooses no baseline
- **WHEN** user selects no baseline source
- **THEN** the skill requires `from_commit`, validates commit exists, and derives range as `<from_commit>..HEAD`

### Requirement: Initialization inference SHALL default to new-only
During initialization without an existing OpenAPI baseline, the skill MUST only infer `new` candidates and MUST NOT infer `updated`.

#### Scenario: Initialization without OpenAPI file
- **WHEN** `docs/api-docs/openapi.yaml` is missing at initialization time
- **THEN** inference output includes `new` candidates only and excludes `updated`/`deleted`

### Requirement: Skill SHALL persist baseline after first successful sync
After first successful sync in initialization flow, the system MUST append a success history record and use it for subsequent time-bounded inference.

#### Scenario: First initialization sync succeeds
- **WHEN** upload succeeds in initialization flow
- **THEN** history record is appended with `synced_at` and subsequent runs use that record as baseline

### Requirement: Skill SHALL provide fast and enhanced analysis levels
The skill MUST provide analysis levels to control cost and depth, defaulting to fast mode.

#### Scenario: Default execution
- **WHEN** user does not specify analysis level
- **THEN** skill runs in fast mode and avoids unnecessary LLM-based semantic enrichment

