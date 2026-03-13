## NEW Requirements

### Requirement: Guided sync pauses for unresolved OpenAPI analysis
The system MUST pause guided sync before upload when generated OpenAPI contains unresolved or low-confidence analysis that requires user review.

#### Scenario: Unresolved validation rules are detected
- **WHEN** request rule analysis leaves unresolved validation semantics
- **THEN** the system MUST write a review artifact describing those unresolved items
- **AND** MUST allow the user or LLM to resolve them before upload

#### Scenario: Unresolved response or security analysis is detected
- **WHEN** response shape or security requirements cannot be determined reliably
- **THEN** the system MUST surface only those unresolved items for review
- **AND** MUST NOT require review of unrelated endpoints
