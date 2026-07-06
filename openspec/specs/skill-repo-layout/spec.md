# skill-repo-layout Specification

## Purpose
定義這個 repo 作為多 skill collection 時的目錄與安裝文件契約，確保 project skills 使用直接、容易尋找的路徑。
## Requirements
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

### Requirement: Repo documents repo-based installation
The repository MUST document repo-based installation for public skills.

#### Scenario: User wants to install a skill
- **WHEN** a user reads the repo installation guide
- **THEN** the guide MUST show a repo-based install command using `npx skills add <owner>/<repo> --skill <skill-name>`
- **AND** MUST list available skills by direct skill name

### Requirement: Laravel API docs skill is distributed from a direct skill path
The `laravel-api-docs` skill MUST be distributed from the direct skill location.

#### Scenario: User browses the repo structure
- **WHEN** the user looks for `laravel-api-docs`
- **THEN** the skill MUST exist at `skills/laravel-api-docs`
- **AND** active repository documents MUST reference the direct skill path instead of `.curated` or legacy flat path variants

