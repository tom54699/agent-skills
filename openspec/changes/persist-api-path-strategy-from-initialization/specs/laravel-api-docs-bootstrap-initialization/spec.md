## MODIFIED Requirements

### Requirement: Skill SHALL require initialization baseline decision when no success history exists
When no successful sync history is available, the skill MUST run an initialization decision step before candidate inference.

#### Scenario: No success history found
- **WHEN** `docs/api-docs/history/apidog-sync-history.jsonl` has no `status=success` record
- **THEN** the skill prompts for baseline source selection: local OpenAPI, Apidog export, or no baseline
- **AND** MUST require the user to confirm an API path strategy before candidate inference continues

### Requirement: Skill SHALL persist baseline after first successful sync
After first successful sync in initialization flow, the system MUST append a success history record and use it for subsequent time-bounded inference.

#### Scenario: First initialization sync succeeds
- **WHEN** upload succeeds in initialization flow
- **THEN** history record is appended with `synced_at`
- **AND** MUST persist the chosen API path strategy for subsequent runs
