## MODIFIED Requirements

### Requirement: Step 8 SHALL ask for Redoc output scope
`guided-sync` Step 8 SHALL ask the user which Redoc output scope to generate when the user chooses to generate HTML. The available scopes SHALL include changed-only Redoc from confirmed candidates and full API Redoc from `docs/api-docs/openapi.yaml`.

#### Scenario: User chooses changed-only Redoc
- **WHEN** Apidog sync succeeds and the user chooses to generate Redoc HTML
- **AND** the user selects changed-only output scope
- **THEN** Step 9 generates Redoc from a subset OpenAPI containing only confirmed `new` and `updated` candidates

#### Scenario: User chooses full Redoc
- **WHEN** Apidog sync succeeds and the user chooses to generate Redoc HTML
- **AND** the user selects full output scope
- **THEN** Step 9 generates Redoc from `docs/api-docs/openapi.yaml`

#### Scenario: User chooses no extra content
- **WHEN** Apidog sync succeeds and the user chooses to generate Redoc HTML
- **AND** the user says no extra content is needed
- **THEN** Step 9 MUST call `gen-html.sh` without `--with-extra`
- **AND** any existing `docs/api-docs/redoc/extra.md` MUST NOT be reused implicitly

#### Scenario: User chooses extra content
- **WHEN** Apidog sync succeeds and the user chooses to include extra HTML content
- **THEN** the LLM MUST draft or refresh current-run extra markdown before Step 9
- **AND** Step 9 MUST render that current-run file via `--with-extra` or `--extra-file FILE`
