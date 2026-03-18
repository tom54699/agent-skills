## Overview

將 `laravel-api-docs` 的多模式流程收斂為單一 `guided-sync`，流程重點為：
1. 由歷史同步點推導 Git 範圍。
2. AI 先提出候選 API 清單。
3. 與使用者討論後鎖定最終清單。
4. 只針對最終清單更新 OpenAPI。
5. 先同步 Apidog，再產生 HTML。

## Flow

1. Preflight
- 檢查 `artisan`、`routes/`、`.env.agents`、`APIDOG_ACCESS_TOKEN`、`APIDOG_PROJECT_ID`。

2. Build baseline and range
- 讀取 `docs/api-docs/history/apidog-sync-history.jsonl` 最後一筆 `status=success`。
- 使用 `synced_at` 切時間範圍，並用該範圍內 commit 與變更檔案進行候選推測。
- 時間格式固定為 UTC ISO 8601（`YYYY-MM-DDTHH:mm:ssZ`）。
- 若無成功歷史，使用 `SYNC_LOOKBACK_COMMITS`（預設 50）做首次候選推測。

3. Candidate inference
- 從 Git 範圍內變更檔案推測候選 endpoints，來源包含 `routes/`、Controller、FormRequest、Resource、Service。
- 產出候選清單：`status | method | path | reason | confidence`。

4. Discussion and finalization
- 顯示候選清單並與使用者討論修正。
- 得到最終清單後鎖定處理範圍。

5. Update and sync
- 深度分析最終清單並更新 `docs/api-docs/openapi.yaml`。
- `deleted` 預設不自動刪除，先輸出待確認清單；確認後才刪除或標記 deprecated。
- 上傳 `docs/api-docs/openapi.yaml` 至 Apidog，並產生衝突清單。
- `updated` 衝突至少比較：summary、description、parameters、requestBody、responses、tags。

6. Derived docs
- 使用者選擇需要時，才由 `docs/api-docs/openapi.yaml` 產生 `docs/api-docs/redoc/api-docs.html`。

7. Sync history write-back
- 上傳成功後 append 一筆 JSON 到 `docs/api-docs/history/apidog-sync-history.jsonl`。

## Data Contract

### `docs/api-docs/history/apidog-sync-history.jsonl`

每行一筆 JSON，範例欄位：
- `sync_id`: string
- `synced_at`: ISO 8601 string
- `from_time`: ISO 8601 string
- `to_time`: ISO 8601 string
- `git_head_commit`: string
- `git_branch`: string
- `openapi_sha256`: string
- `apidog_project_id`: string
- `imported_count`: number
- `updated_count`: number
- `skipped_count`: number
- `conflict_count`: number
- `status`: `success` | `failed`

只以 `status=success` 作為下一次推測基準。

## Non-goals

- 本次不重寫所有既有腳本實作細節。
- 本次不處理 npm 發布流程。
