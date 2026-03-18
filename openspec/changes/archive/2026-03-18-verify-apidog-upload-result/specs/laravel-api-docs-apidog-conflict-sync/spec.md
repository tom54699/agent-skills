## MODIFIED Requirements

### Requirement: Updated endpoints produce a conflict file before Apidog sync
The system MUST evaluate confirmed `updated` endpoints for local-versus-remote conflicts before finalizing Apidog sync, and MUST persist the conflict result to `docs/api-docs/conflicts/<timestamp>.json`.

#### Scenario: Import counters report success but confirmed endpoints are absent after export
- **WHEN** Apidog import returns HTTP 200/201
- **AND** a post-upload export still lacks one or more confirmed active endpoints
- **THEN** the system MUST treat the sync as failed
- **AND** the system MUST NOT append a success history entry

#### Scenario: Candidate-driven upload is verified after import
- **WHEN** `upload-apidog.sh` receives a confirmed candidate file
- **THEN** the system MUST re-export the remote OpenAPI after upload
- **AND** MUST verify that each confirmed `new` or `updated` endpoint exists in remote `paths`

#### Scenario: Full upload without candidate file is verified conservatively
- **WHEN** `upload-apidog.sh` runs without a confirmed candidate file
- **THEN** the system MUST still re-export the remote OpenAPI
- **AND** MUST reject the sync if the exported `paths` map is empty
