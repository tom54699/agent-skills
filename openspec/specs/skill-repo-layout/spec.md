# skill-repo-layout Specification

## Purpose
定義這個 repo 作為多 skill collection 時的目錄分層與安裝文件契約，確保穩定 skill、實驗 skill 與對外安裝入口保持一致。
## Requirements
### Requirement: Stable and experimental skills are separated
The repository MUST separate installable stable skills from experimental skills under `skills/.curated/` and `skills/.experimental/`.

#### Scenario: Stable skill is published from this repo
- **WHEN** a skill is considered stable enough for normal installation
- **THEN** it MUST live under `skills/.curated/<skill-name>`
- **AND** repo-level documentation MUST present it as a curated skill

#### Scenario: Experimental skill is kept in the repo
- **WHEN** a skill is still under active exploration or may break compatibility
- **THEN** it MUST live under `skills/.experimental/<skill-name>`
- **AND** repo-level documentation MUST mark it as experimental

### Requirement: Repo documents repo-based installation
The repository MUST document repo-based installation for public skills.

#### Scenario: User wants to install a curated skill
- **WHEN** a user reads the repo installation guide
- **THEN** the guide MUST show a repo-based install command using `npx skills add <owner>/<repo> --skill <skill-name>`
- **AND** MUST explain which skills are curated versus experimental

### Requirement: Laravel API docs skill is distributed as a curated skill
The `laravel-api-docs` skill MUST be distributed from the curated skill location.

#### Scenario: User browses the repo structure
- **WHEN** the user looks for `laravel-api-docs`
- **THEN** the skill MUST exist at `skills/.curated/laravel-api-docs`
- **AND** active repository documents MUST reference the curated path instead of the legacy flat skill path
