## ADDED Requirements

### Requirement: Docker server deploy skill is distributed from a direct skill path
The `docker-server-deploy` skill MUST be distributed from the direct skill location.

#### Scenario: User looks for the deployment skill
- **WHEN** the user looks for the skill that deploys projects to a Linux server with Docker Compose and CI/CD
- **THEN** the skill MUST exist at `skills/docker-server-deploy`
- **AND** active repository documents MUST reference the direct skill path
