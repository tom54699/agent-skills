# laravel-api-docs-guided-sync Specification

## Purpose
TBD - created by archiving change refine-laravel-api-docs-guided-sync. Update Purpose after archive.
## Requirements
### Requirement: Skill SHALL use a single guided-sync mode
`laravel-api-docs` skill MUST provide one execution mode named `guided-sync` and MUST NOT require users to choose among multiple generation modes during normal use.

#### Scenario: User triggers API docs sync
- **WHEN** user says phrases such as `幫我產生 API 文件`, `更新 API 文件`, `文件同步`, or `sync api docs`
- **THEN** the skill executes `guided-sync` flow without presenting mode selection options

### Requirement: Skill SHALL generate candidate API list from sync baseline and Git range
The skill MUST infer a candidate endpoint list from repository changes within a time-bounded Git range derived from the latest successful sync record.

#### Scenario: Successful baseline exists
- **WHEN** `docs/api-docs/history/apidog-sync-history.jsonl` has at least one `success` record
- **THEN** the skill uses `last_success.synced_at` to build a time-bounded Git range and infer candidate endpoints from commits in that range
- **AND** the time values MUST use UTC ISO 8601 format (`YYYY-MM-DDTHH:mm:ssZ`)

#### Scenario: No successful baseline exists
- **WHEN** no `success` record exists
- **THEN** the skill infers candidates from a bounded recent history window and marks lower confidence accordingly
- **AND** the bounded window size MUST be configurable via `SYNC_LOOKBACK_COMMITS` (default: 50)

### Requirement: Skill SHALL require user confirmation on the final endpoint list
The skill MUST present a candidate endpoint list and MUST confirm the final target list with the user before deep analysis and document update.

#### Scenario: Candidate list has mistakes
- **WHEN** the user modifies candidate endpoints (add/remove/reclassify)
- **THEN** the skill updates the target list and only processes the confirmed list

### Requirement: Skill SHALL keep OpenAPI as sync source and HTML as derived output
The skill MUST update `docs/api-docs/openapi.yaml`, sync that file to Apidog first, then optionally generate HTML from the same OpenAPI document. When formal HTML generation runs, the skill MUST keep `docs/api-docs/redoc/` as the latest stable entry and MUST also persist a timestamped version snapshot under `docs/api-docs/versions/<version-id>/`.

#### Scenario: Regular sync flow
- **WHEN** endpoint analysis and OpenAPI update complete
- **THEN** the skill uploads `docs/api-docs/openapi.yaml` to Apidog before any HTML generation step

#### Scenario: Formal HTML generation preserves a version snapshot
- **WHEN** Apidog sync succeeds and the user chooses to generate Redoc HTML
- **THEN** the skill generates latest HTML under `docs/api-docs/redoc/`
- **AND** persists the same HTML output and current OpenAPI file under `docs/api-docs/versions/<version-id>/`

### Requirement: Skill SHALL persist sync history after successful upload
After each successful Apidog upload, the skill MUST append one JSON line to `docs/api-docs/history/apidog-sync-history.jsonl`.

#### Scenario: Upload succeeds
- **WHEN** Apidog upload returns success
- **THEN** the skill appends a record including `sync_id`, `synced_at`, `from_time`, `to_time`, `git_head_commit`, `git_branch`, `openapi_sha256`, `apidog_project_id`, `imported_count`, `updated_count`, `skipped_count`, `conflict_count`, and `status`

### Requirement: Step 7 uploads only confirmed candidate endpoints to Apidog
`guided-sync` Step 7 的 Apidog 上傳 SHALL 以 delta 模式執行：提供 confirmed candidate file 時，`upload-apidog.sh` 自動過濾 payload，只上傳本次 confirmed 的 `new` 與 `updated` endpoint；`--no-delta` 可回退全量行為。

SKILL.md 的 `upload-apidog.sh` 呼叫範例 SHALL 更新為：
```bash
bash "$SKILL_DIR/upload-apidog.sh" \
  --openapi docs/api-docs/openapi.yaml \
  --candidate-file docs/api-docs/candidates/<timestamp>.confirmed.json
```

（delta 為預設行為，不需額外 flag；全量上傳需明確加 `--no-delta`）

#### Scenario: Guided sync Step 7 sends delta payload
- **WHEN** Step 7 執行 `upload-apidog.sh` 並提供 `--candidate-file`
- **THEN** Apidog 只收到本次 confirmed candidates 對應的 endpoint，其他既有 API 不被觸動

#### Scenario: Full rebuild uses --no-delta
- **WHEN** 使用者要求「完整重建」
- **THEN** Step 7 以 `--no-delta` 呼叫 `upload-apidog.sh`，上傳完整 spec

### Requirement: Step 7 performs path strategy alignment check before uploading
`guided-sync` Step 7 SHALL 在上傳至 Apidog 前自動執行 path strategy alignment check：`upload-apidog.sh` 比對本地與遠端 path strategy，不一致時阻擋並提示使用者確認。

SKILL.md Step 7 SHALL 補充：
- Alignment check 為自動執行，不需使用者額外操作
- 若 check 阻擋，使用者可選擇：調整 `path_strategy` 後重新執行，或確認無誤後加 `--skip-alignment-check` 繼續
- `--skip-alignment-check` 適用於 CI 或已知環境，不建議常態使用

#### Scenario: Step 7 alignment check blocks on mismatch
- **WHEN** Step 7 偵測到 local 與 remote path strategy 不一致
- **THEN** 上傳中止，LLM 向使用者說明差異並提供下一步選項

#### Scenario: Step 7 alignment check passes silently
- **WHEN** Step 7 偵測到 local 與 remote path strategy 一致，或遠端為空
- **THEN** 上傳繼續，不輸出額外訊息

### Requirement: Skill SHALL handle updated endpoints with conflict list
The skill MUST generate a conflict list for updated endpoints and MUST default unresolved conflicts to keep remote content.

#### Scenario: Updated endpoint has conflict
- **WHEN** local OpenAPI and remote Apidog content differ for an updated endpoint
- **THEN** the skill adds a conflict item with `keep_remote`, `use_local`, and `manual_merge` actions and applies `keep_remote` unless user explicitly chooses otherwise
- **AND** conflict detection MUST compare at least `summary`, `description`, `parameters`, `requestBody`, `responses`, and `tags`

### Requirement: Skill SHALL require explicit confirmation before deleting endpoints
The skill MUST NOT auto-delete endpoints in OpenAPI during guided sync unless the user explicitly confirms deletion handling.

#### Scenario: Candidate list includes deleted endpoint
- **WHEN** an endpoint is detected as `deleted`
- **THEN** the skill outputs a pending deletion list and waits for user decision to either delete or mark deprecated
