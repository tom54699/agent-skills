## MODIFIED Requirements

### Requirement: Project skills use direct paths
The repository MUST store active project skills directly under `skills/<skill-name>/` instead of requiring curated or experimental subdirectories.

#### Scenario: Skill is available from this repo
- **WHEN** a skill is part of the active repository skill collection
- **THEN** it MUST live under `skills/<skill-name>`
- **AND** repo-level documentation MUST reference the direct skill path

#### Scenario: Maturity is documented without path classification
- **WHEN** a skill is still under active exploration or may change compatibility
- **THEN** the repository MAY describe that status in documentation or skill metadata
- **AND** the skill MUST NOT require a `.curated` or `.experimental` path segment

#### Scenario: Business logic workflow skill is available
- **WHEN** the user looks for the business logic documentation workflow
- **THEN** the skill MUST exist at `skills/business-logic-workflow`
- **AND** active repository documents MUST reference the direct skill path

#### Scenario: Development workflow skill is available
- **WHEN** the user looks for the AI development workflow initializer
- **THEN** the skill MUST exist at `skills/development-workflow`
- **AND** active repository documents MUST reference the direct skill path
