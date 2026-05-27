## ADDED Requirements

### Requirement: System SHALL discover Apidog API tree before folder-aware upload
The system SHALL fetch the Apidog project API tree with `GET https://api.apidog.com/api/v1/projects/{projectId}/api-tree-list` before folder-aware upload is applied. The request MUST include `Authorization: Bearer {token}` and `X-Apidog-Api-Version: 2024-03-28`.

#### Scenario: API tree discovery succeeds
- **WHEN** Apidog returns `success: true` and a tree in `data`
- **THEN** the system stores or passes the tree to the folder mapping step
- **AND** the upload flow can continue with folder-aware behavior

#### Scenario: Wrong API prefix redirects
- **WHEN** the tree request receives an HTTP redirect to a documentation page
- **THEN** the system reports that `/api/v1/` must be used for `api-tree-list`
- **AND** the system MUST NOT treat the response as a valid empty tree

#### Scenario: API tree discovery lacks privilege
- **WHEN** Apidog returns a permission error such as `No project guest privilege`
- **THEN** the system reports that the token or project permission is insufficient
- **AND** folder-aware upload MUST require manual fallback confirmation or explicit `folder_id` values

### Requirement: System SHALL build folder mapping from Apidog API tree
The system SHALL parse Apidog API tree nodes into a mapping that can resolve candidate endpoints to Apidog folder IDs. `apiDetailFolder` nodes SHALL derive folder IDs from keys such as `apiDetailFolder.1417834`; `apiDetail` nodes SHALL use `api.path` and `api.folderId` when present.

#### Scenario: Existing endpoint has exact folder mapping
- **WHEN** an `apiDetail` node contains path `/api/admin/users` and `folderId: 1417834`
- **THEN** a candidate with the same normalized path resolves to folder ID `1417834`

#### Scenario: New endpoint uses longest prefix mapping
- **WHEN** a candidate path has no exact `apiDetail` match
- **AND** multiple known path prefixes match the candidate path
- **THEN** the system chooses the folder ID from the longest matching prefix

#### Scenario: Folder key cannot be parsed
- **WHEN** an `apiDetailFolder` key does not contain a numeric suffix
- **THEN** that folder node is skipped for folder ID derivation
- **AND** the system continues parsing other valid nodes

### Requirement: Candidate confirmation SHALL allow folder ID override
The confirmed candidate artifact SHALL support an optional `folder_id` field per candidate. When present, `folder_id` SHALL override automatic folder mapping for that candidate.

#### Scenario: User provides folder override
- **WHEN** a confirmed candidate includes `folder_id: 1417834`
- **THEN** upload uses folder ID `1417834` for that candidate regardless of prefix mapping

#### Scenario: No folder override exists
- **WHEN** a confirmed candidate does not include `folder_id`
- **THEN** upload resolves the candidate folder through the Apidog tree mapping rules

### Requirement: Unmapped candidates SHALL require explicit fallback handling
The system SHALL identify candidates that cannot be mapped to a folder ID. It MUST report those candidates and only use root folder `0` after explicit fallback confirmation or an explicit configuration path.

#### Scenario: Candidate cannot be mapped
- **WHEN** a candidate has no `folder_id`, no exact tree match, and no prefix match
- **THEN** the system reports that candidate as unmapped
- **AND** upload does not silently assign root folder `0`

#### Scenario: User confirms root fallback
- **WHEN** the user confirms root folder fallback for unmapped candidates
- **THEN** upload assigns those candidates to `targetEndpointFolderId: 0`
