## ADDED Requirements

### Requirement: Guided sync SHALL present a concise candidate list before confirmation
The system MUST present inferred API candidates to the user as a concise list before any OpenAPI update occurs.

#### Scenario: Initial candidate review
- **WHEN** `infer-candidates.sh` finishes candidate inference
- **THEN** the user sees a list containing only `status`, `method`, and `path` by default
- **AND** detailed reasoning is only shown when needed for clarification

### Requirement: Guided sync SHALL support iterative candidate confirmation
The system MUST allow the user to repeatedly adjust the candidate list until explicit confirmation is given.

#### Scenario: User removes or adds APIs
- **WHEN** the user removes a candidate or manually adds an API endpoint
- **THEN** the system regenerates and re-displays the working list
- **AND** it does not proceed to OpenAPI update until the user explicitly confirms the final list

### Requirement: OpenAPI update SHALL be driven by the confirmed final list
The system MUST use the confirmed final candidate list as the only input scope for OpenAPI updates.

#### Scenario: Final list confirmed
- **WHEN** the user confirms the candidate list
- **THEN** the system persists a structured confirmed list artifact
- **AND** subsequent OpenAPI update processes only the endpoints contained in that confirmed list

#### Scenario: Unconfirmed candidates exist
- **WHEN** the user has not explicitly confirmed the working list
- **THEN** the system MUST NOT update `docs/api-docs/openapi.yaml`

### Requirement: Apidog sync and HTML generation SHALL happen after final-list-driven OpenAPI update
The system MUST keep the downstream order unchanged once the final list is confirmed.

#### Scenario: Final list applied successfully
- **WHEN** confirmed candidates have been applied to `docs/api-docs/openapi.yaml`
- **THEN** the system syncs Apidog next
- **AND** it asks about HTML generation only after the sync step completes
