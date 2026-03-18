## ADDED Requirements

### Requirement: Updated endpoints produce a conflict file before Apidog sync
The system MUST evaluate confirmed `updated` endpoints for local-versus-remote conflicts before finalizing Apidog sync, and MUST persist the conflict result to `docs/api-docs/conflicts/<timestamp>.json`.

#### Scenario: No updated endpoints exist
- **WHEN** `upload-apidog.sh` receives no confirmed `updated` endpoints
- **THEN** the system MUST skip conflict comparison
- **AND** the sync flow MAY continue without generating a conflict file

#### Scenario: Updated endpoint differs from remote definition
- **WHEN** a confirmed `updated` endpoint differs from the remote definition in `summary`, `description`, `parameters`, `requestBody`, `responses`, or `tags`
- **THEN** the system MUST write a conflict entry to `docs/api-docs/conflicts/<timestamp>.json`
- **AND** each entry MUST include `method`, `path`, `conflict_type`, `reason`, and `suggested_action`

#### Scenario: Unconfirmed conflicts default to keep_remote
- **WHEN** conflicts are detected and no explicit strategy is provided
- **THEN** the system MUST treat the conflict strategy as `keep_remote`
- **AND** the sync process MUST avoid overwriting the conflicting remote operation with local content

#### Scenario: Manual merge is requested
- **WHEN** the conflict strategy is `manual_merge`
- **THEN** the system MUST generate the conflict file
- **AND** the automatic sync step MUST stop before applying the conflicting update

### Requirement: Sync history records conflict count from generated conflict results
The system MUST derive `conflict_count` from the generated conflict evaluation result rather than relying on a caller-supplied placeholder value.

#### Scenario: Conflict file contains entries
- **WHEN** conflict evaluation produces one or more entries
- **THEN** the appended history record MUST use that entry count as `conflict_count`

#### Scenario: Conflict evaluation finds no differences
- **WHEN** conflict evaluation completes without entries
- **THEN** the appended history record MUST record `conflict_count` as `0`
