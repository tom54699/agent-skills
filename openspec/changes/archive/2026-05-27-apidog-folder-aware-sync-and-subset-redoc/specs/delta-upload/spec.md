## ADDED Requirements

### Requirement: Delta upload SHALL group confirmed candidates by target folder ID
When folder-aware upload is enabled, delta upload SHALL group confirmed `new` and `updated` candidates by resolved target folder ID and create one upload payload per folder group.

#### Scenario: Candidates resolve to multiple folders
- **WHEN** confirmed candidates resolve to folder IDs `1417834` and `1417999`
- **THEN** upload creates one delta payload for folder `1417834`
- **AND** upload creates one delta payload for folder `1417999`

#### Scenario: Folder batch payload contains only that folder candidates
- **WHEN** a folder group contains 2 candidates
- **THEN** that group's upload payload `.paths` contains only those 2 candidates
- **AND** shared OpenAPI nodes such as `info`, `servers`, `components`, and `tags` are preserved

### Requirement: Delta upload SHALL set targetEndpointFolderId per folder batch
Each folder-aware delta upload request SHALL set `options.targetEndpointFolderId` to the folder ID for that batch. Folder-aware uploads SHALL set `options.updateFolderOfChangedEndpoint` to `true` so changed endpoints can move to the resolved folder when needed.

#### Scenario: Uploading one folder batch
- **WHEN** a folder batch targets folder ID `1417834`
- **THEN** the import request contains `targetEndpointFolderId: 1417834`
- **AND** the request contains `updateFolderOfChangedEndpoint: true`

### Requirement: Folder-aware delta upload SHALL write success history only after all batches verify
Folder-aware delta upload SHALL treat all folder batches as one guided-sync operation. The system SHALL append success history only after every batch uploads successfully and post-upload verification passes for all confirmed `new` and `updated` candidates.

#### Scenario: All folder batches succeed
- **WHEN** every folder batch upload succeeds
- **AND** post-upload verification confirms all confirmed `new` and `updated` candidates exist remotely
- **THEN** the system appends one success record to `docs/api-docs/history/apidog-sync-history.jsonl`

#### Scenario: One folder batch fails
- **WHEN** any folder batch upload fails or post-upload verification fails
- **THEN** the whole guided-sync upload is treated as failed
- **AND** the system does not append a success history record

### Requirement: Folder-aware delta upload SHALL remain compatible with full upload controls
Folder-aware grouping SHALL apply only when delta upload is active and confirmed candidate data is available. `--no-delta` SHALL continue to force full upload behavior.

#### Scenario: Full rebuild bypasses folder grouping
- **WHEN** upload is called with `--no-delta`
- **THEN** folder-aware delta grouping is not applied
- **AND** upload uses the full OpenAPI payload according to full upload behavior

#### Scenario: No candidate file bypasses folder grouping
- **WHEN** upload is called without `--candidate-file`
- **THEN** folder-aware delta grouping is not applied
