## MODIFIED Requirements

### Requirement: Updated endpoints produce a conflict file before Apidog sync
The system MUST evaluate confirmed `updated` endpoints for local-versus-remote conflicts before finalizing Apidog sync, and MUST persist the conflict result to `docs/api-docs/conflicts/<timestamp>.json`.

#### Scenario: Remote operation is missing for a confirmed updated endpoint
- **WHEN** a confirmed `updated` endpoint exists in local OpenAPI but the exported remote OpenAPI has no matching `path + method`
- **THEN** the system MUST record the result with `conflict_type = "missing_remote_endpoint"`
- **AND** the conflict entry MUST mark `blocking = false`
- **AND** the sync flow MUST allow the local operation to remain eligible for upload

#### Scenario: Remote operation exists and differs from local definition
- **WHEN** a confirmed `updated` endpoint exists in both local and remote OpenAPI and differs in `summary`, `description`, `parameters`, `requestBody`, `responses`, or `tags`
- **THEN** the system MUST mark the conflict entry as `blocking = true`
- **AND** the sync strategy MUST decide whether to keep remote, use local, or stop for manual merge

#### Scenario: keep_remote only preserves true remote conflicts
- **WHEN** the conflict strategy is `keep_remote`
- **THEN** the system MUST preserve remote operations only for conflict entries where `blocking = true`
- **AND** the system MUST NOT suppress local upload of `missing_remote_endpoint` entries
