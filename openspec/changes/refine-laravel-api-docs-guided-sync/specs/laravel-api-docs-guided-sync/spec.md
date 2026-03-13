## ADDED Requirements

### Requirement: Skill SHALL use a single guided-sync mode
`laravel-api-docs` skill MUST provide one execution mode named `guided-sync` and MUST NOT require users to choose among multiple generation modes during normal use.

#### Scenario: User triggers API docs sync
- **WHEN** user says phrases such as `幫我產生 API 文件`, `更新 API 文件`, `文件同步`, or `sync api docs`
- **THEN** the skill executes `guided-sync` flow without presenting mode selection options

### Requirement: Skill SHALL generate candidate API list from sync baseline and Git range
The skill MUST infer a candidate endpoint list from repository changes within a time-bounded Git range derived from the latest successful sync record.

#### Scenario: Successful baseline exists
- **WHEN** `docs/api-docs/history/apidog-sync-history.jsonl` has at least one `success` record
- **THEN** the skill uses `last_success.synced_at` to build a time-bounded Git range and infer candidate endpoints from commits in that range
- **AND** the time values MUST use UTC ISO 8601 format (`YYYY-MM-DDTHH:mm:ssZ`)

#### Scenario: No successful baseline exists
- **WHEN** no `success` record exists
- **THEN** the skill infers candidates from a bounded recent history window and marks lower confidence accordingly
- **AND** the bounded window size MUST be configurable via `SYNC_LOOKBACK_COMMITS` (default: 50)

### Requirement: Skill SHALL require user confirmation on the final endpoint list
The skill MUST present a candidate endpoint list and MUST confirm the final target list with the user before deep analysis and document update.

#### Scenario: Candidate list has mistakes
- **WHEN** the user modifies candidate endpoints (add/remove/reclassify)
- **THEN** the skill updates the target list and only processes the confirmed list

### Requirement: Skill SHALL keep OpenAPI as sync source and HTML as derived output
The skill MUST update `docs/api-docs/openapi.yaml`, sync that file to Apidog first, then optionally generate HTML from the same OpenAPI document.

#### Scenario: Regular sync flow
- **WHEN** endpoint analysis and OpenAPI update complete
- **THEN** the skill uploads `docs/api-docs/openapi.yaml` to Apidog before any HTML generation step

### Requirement: Skill SHALL persist sync history after successful upload
After each successful Apidog upload, the skill MUST append one JSON line to `docs/api-docs/history/apidog-sync-history.jsonl`.

#### Scenario: Upload succeeds
- **WHEN** Apidog upload returns success
- **THEN** the skill appends a record including `sync_id`, `synced_at`, `from_time`, `to_time`, `git_head_commit`, `git_branch`, `openapi_sha256`, `apidog_project_id`, `imported_count`, `updated_count`, `skipped_count`, `conflict_count`, and `status`

### Requirement: Skill SHALL handle updated endpoints with conflict list
The skill MUST generate a conflict list for updated endpoints and MUST default unresolved conflicts to keep remote content.

#### Scenario: Updated endpoint has conflict
- **WHEN** local OpenAPI and remote Apidog content differ for an updated endpoint
- **THEN** the skill adds a conflict item with `keep_remote`, `use_local`, and `manual_merge` actions and applies `keep_remote` unless user explicitly chooses otherwise
- **AND** conflict detection MUST compare at least `summary`, `description`, `parameters`, `requestBody`, `responses`, and `tags`

### Requirement: Skill SHALL require explicit confirmation before deleting endpoints
The skill MUST NOT auto-delete endpoints in OpenAPI during guided sync unless the user explicitly confirms deletion handling.

#### Scenario: Candidate list includes deleted endpoint
- **WHEN** an endpoint is detected as `deleted`
- **THEN** the skill outputs a pending deletion list and waits for user decision to either delete or mark deprecated
