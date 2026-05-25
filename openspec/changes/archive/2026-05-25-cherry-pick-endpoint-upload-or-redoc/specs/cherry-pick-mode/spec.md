## ADDED Requirements

### Requirement: Cherry-pick mode is triggered by explicit user phrasing
當使用者說「只想上傳這幾個 API」、「單獨產這幾個 endpoint 的 Redoc」、「cherry-pick」或「挑幾個 API」時，系統 SHALL 進入 cherry-pick 模式，不走完整 guided-sync 流程。

#### Scenario: Cherry-pick trigger recognized
- **WHEN** 使用者輸入含有 cherry-pick 觸發短語
- **THEN** LLM 進入 cherry-pick 模式，列出 `openapi.yaml` 現有 endpoint 清單供選取

#### Scenario: Guided-sync trigger is not confused with cherry-pick
- **WHEN** 使用者說「幫我產生 API 文件」、「更新 API 文件」
- **THEN** 進入 guided-sync 主流程，不進入 cherry-pick 模式

### Requirement: LLM assembles a temporary subset spec from selected endpoints
LLM SHALL 從 `docs/api-docs/openapi.yaml` 複製使用者選定的 paths，保留完整 `info`、`servers`、`components`、`tags`，組成 temp subset spec 並寫入 `/tmp/cherry-pick-<timestamp>.json`。Subset spec 不得修改或覆蓋 `docs/api-docs/openapi.yaml`。

#### Scenario: Subset spec contains selected paths and shared nodes
- **WHEN** 使用者選定 3 個 endpoint
- **THEN** temp spec 的 `.paths` 只含這 3 個 path key，`info`/`servers`/`components` 完整保留

#### Scenario: openapi.yaml is not modified
- **WHEN** cherry-pick 任何步驟執行後
- **THEN** `docs/api-docs/openapi.yaml` 內容與 cherry-pick 前相同

### Requirement: Cherry-pick supports descriptive endpoint selection
LLM SHALL 支援描述式選取（例如「跟付款相關的 API」），從 `openapi.yaml` 比對 tag、path、summary 後推薦候選，讓使用者確認或調整。

#### Scenario: Descriptive selection resolved to explicit list
- **WHEN** 使用者說「付款相關的 API」
- **THEN** LLM 列出推測的 endpoint 清單，使用者確認後才組 subset spec

### Requirement: Cherry-pick upload does not write sync history
Cherry-pick 上傳 Apidog 時 SHALL 使用 `--skip-history --no-delta`，不寫入 `apidog-sync-history.jsonl`，不影響 guided-sync 的 Step 3 baseline。

#### Scenario: Cherry-pick upload skips history
- **WHEN** cherry-pick 模式上傳 Apidog 完成
- **THEN** `docs/api-docs/history/apidog-sync-history.jsonl` 無新增記錄

### Requirement: Cherry-pick explicitly warns that conflict detection is skipped
cherry-pick 上傳前 SHALL 告知使用者：本次不執行 conflict detection，若遠端有手動修改可能被覆蓋。

#### Scenario: User is warned before cherry-pick upload
- **WHEN** 使用者確認要上傳 cherry-picked endpoints
- **THEN** LLM 在上傳前說明「本次跳過 conflict detection，遠端手動修改將被覆蓋」，使用者再次確認後才執行
