## ADDED Requirements

### Requirement: Guided sync SHALL run automated preflight before candidate inference
The system MUST execute an automated preflight check before candidate inference begins.

#### Scenario: Guided sync starts
- **WHEN** the user triggers API docs sync
- **THEN** the system runs `preflight.sh` first
- **AND** it MUST NOT continue to candidate inference if preflight fails

### Requirement: Preflight SHALL validate required Laravel and Apidog prerequisites
The system MUST validate the required project and environment prerequisites defined by the skill.

#### Scenario: Missing .env.agents
- **WHEN** `.env.agents` does not exist
- **THEN** preflight fails with a clear error and non-zero exit code

#### Scenario: Missing APIDOG credentials
- **WHEN** `.env.agents` exists but lacks `APIDOG_ACCESS_TOKEN` or `APIDOG_PROJECT_ID`
- **THEN** preflight fails with a clear error and non-zero exit code

#### Scenario: Missing .gitignore rule
- **WHEN** `.gitignore` does not include `.env.agents`
- **THEN** preflight fails with a clear error and non-zero exit code

### Requirement: Preflight SHALL prepare required directory structure
The system MUST ensure the guided-sync working directories exist before later steps run.

#### Scenario: Docs directories absent
- **WHEN** `docs/api-docs/` or its expected child directories do not exist
- **THEN** preflight creates them before reporting success

### Requirement: Preflight SHALL emit structured output for orchestration
The system MUST emit structured output that downstream orchestration can inspect.

#### Scenario: Preflight succeeds
- **WHEN** all checks pass
- **THEN** preflight outputs JSON including check results, created directories, and `ready=true`
