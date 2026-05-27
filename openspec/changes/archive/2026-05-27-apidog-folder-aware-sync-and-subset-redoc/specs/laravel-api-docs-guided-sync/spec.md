## ADDED Requirements

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

### Requirement: Step 9 SHALL generate changed-only Redoc from subset OpenAPI
When changed-only Redoc is selected, `guided-sync` Step 9 SHALL create a temporary or versioned subset OpenAPI from the confirmed candidate file and pass that file to `gen-html.sh --openapi <subset>`. The subset SHALL include only confirmed `new` and `updated` endpoint paths while preserving shared OpenAPI nodes.

#### Scenario: Changed-only Redoc uses subset OpenAPI
- **WHEN** the confirmed candidate file contains 3 `new` or `updated` endpoints
- **THEN** the subset OpenAPI `.paths` contains only those confirmed endpoints
- **AND** `gen-html.sh` is called with `--openapi <subset>`

#### Scenario: Deleted candidates are excluded from changed-only Redoc
- **WHEN** the confirmed candidate file contains `deleted` candidates
- **THEN** those deleted candidates are not included in the changed-only Redoc subset

#### Scenario: Changed-only Redoc does not overwrite stable full entry by default
- **WHEN** Step 9 generates changed-only Redoc
- **THEN** the output SHALL NOT overwrite `docs/api-docs/redoc/index.html` or `docs/api-docs/redoc/api-docs.html` unless the user explicitly confirms replacing the stable entry

### Requirement: Step 7 SHALL use Apidog folder-aware upload when folder mapping is available
`guided-sync` Step 7 SHALL use Apidog folder-aware upload for confirmed candidate delta uploads when Apidog API tree mapping or explicit candidate `folder_id` values are available.

#### Scenario: Folder mapping is available
- **WHEN** Step 7 resolves folder IDs for confirmed candidates
- **THEN** upload groups candidates by folder ID
- **AND** each upload batch uses the resolved `targetEndpointFolderId`

#### Scenario: Folder mapping is unavailable
- **WHEN** Step 7 cannot fetch API tree and no confirmed candidates contain `folder_id`
- **THEN** the system reports that folder-aware upload is unavailable
- **AND** the user must confirm fallback behavior before upload continues
