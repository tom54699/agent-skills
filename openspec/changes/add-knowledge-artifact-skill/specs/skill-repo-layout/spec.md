## ADDED Requirements

### Requirement: Knowledge artifact skill is distributed from a direct skill path
The `knowledge-artifact` skill MUST be distributed from the direct skill location.

#### Scenario: User looks for the artifact skill
- **WHEN** the user looks for the skill that turns topics into HTML explainers and manages them on the Knowledge Platform
- **THEN** the skill MUST exist at `skills/knowledge-artifact`
- **AND** active repository documents MUST reference the direct skill path
