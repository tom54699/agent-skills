## MODIFIED Requirements

### Requirement: Generated Documentation Drafts
The skill MAY generate documentation drafts from the compact index, but generated drafts SHALL remain local-regenerate output and SHALL NOT become source of truth without review.

#### Scenario: Generate project map draft
- **WHEN** documentation draft generation is requested
- **THEN** the skill MAY write `docs/generated/project-map.md`
- **AND** the file MUST be labelled as a generated draft requiring review
- **AND** the file MUST NOT be committed by default

#### Scenario: Generate business logic draft
- **WHEN** business logic draft generation is requested
- **THEN** the skill MAY write `docs/generated/business-logic-draft.md`
- **AND** the file MUST be labelled as a generated draft requiring review
- **AND** the file MUST NOT be committed by default
