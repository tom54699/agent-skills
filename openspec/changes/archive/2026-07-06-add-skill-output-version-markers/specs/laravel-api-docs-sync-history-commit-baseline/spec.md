## ADDED Requirements

### Requirement: Sync history records SHALL carry a schema version
The system SHALL include a `schema_version` field in newly appended sync history records, and MUST tolerate its absence in older records.

#### Scenario: New history record includes schema version
- **WHEN** guided-sync appends a new record to `docs/api-docs/history/apidog-sync-history.jsonl`
- **THEN** the record MUST include a `schema_version` field

#### Scenario: Legacy records without schema version remain valid
- **WHEN** older history records exist without `schema_version`
- **THEN** the system MUST continue accepting those records
- **AND** it MUST NOT require manual history migration before the next run
