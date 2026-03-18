# Laravel API Docs Guided-Sync 流程說明

這份文件整理 `skills/.curated/laravel-api-docs` 目前最完整的 guided-sync 執行流程，目的不是介紹單一腳本，而是說清楚整條鏈路的責任邊界、輸入輸出與排錯方式。

適用情境：
- Laravel 專案日常同步 API 文件
- 第一次導入 `laravel-api-docs`
- 排查 candidate 清單、OpenAPI merge 或 Apidog sync 的異常

## 1. 核心原則

1. 候選推測只回答「本次變更影響哪些 API」。
2. `docs/api-docs/openapi.yaml` 是同步 Apidog 的唯一來源。
3. baseline 不負責找出所有歷史缺漏 API；baseline 只用在 diagnostics、OpenAPI merge 與 `deleted` 判定。
4. 同步順序固定：candidate inference -> 使用者確認 -> 更新 OpenAPI -> 同步 Apidog -> 視需求產生 HTML。
5. 成功同步後必須寫入 history，供下一次日常推測使用。

## 2. 目錄與資料契約

主要檔案：
- `docs/api-docs/openapi.yaml`
- `docs/api-docs/history/apidog-sync-history.jsonl`
- `docs/api-docs/candidates/<timestamp>.json`
- `docs/api-docs/candidates/<timestamp>.confirmed.json`
- `docs/api-docs/conflicts/<timestamp>.json`
- `docs/api-docs/reviews/openapi-review.<timestamp>.json`
- `docs/api-docs/reviews/<timestamp>.approved.json`
- `docs/api-docs/redoc/index.html`
- `docs/api-docs/redoc/api-docs.html`

history 每筆至少包含：
- `sync_id`
- `synced_at`
- `from_time`
- `to_time`
- `git_head_commit`
- `git_branch`
- `openapi_sha256`
- `apidog_project_id`
- `imported_count`
- `updated_count`
- `skipped_count`
- `conflict_count`
- `status`

重要約束：
- `apidog-sync-history.jsonl` 必須使用一行一筆 compact JSON。
- `git_head_commit` 是日常模式的主基準。
- `synced_at` 是 fallback 與觀測欄位，不再是日常 candidate inference 的唯一依據。

## 3. 流程總覽

### Step 1. Preflight

目標是確認執行環境正確，而不是開始分析程式。

至少檢查：
- Laravel 專案根目錄存在 `artisan` 與 `routes/`
- `.env.agents` 有 `APIDOG_ACCESS_TOKEN`、`APIDOG_PROJECT_ID`
- `.gitignore` 已忽略 `.env.agents`
- `jq`、`yq`、`php` 可用
- `php -n artisan route:list --json` 可成功輸出合法 JSON

若 preflight 失敗，流程必須直接中止。

### Step 2. 決定模式

guided-sync 只有兩種高階模式：

1. 日常模式
- `history` 有最後一筆 `status=success`
- 代表專案已經有成功同步基準

2. 初始化模式
- 沒有任何成功同步紀錄
- 必須由使用者提供 `--from-commit`
- 使用者還需要選 baseline 來源：
  - 本地 OpenAPI
  - 從 Apidog 匯出後落地
  - 無 baseline

### Step 3. 收斂 Git 範圍

#### 日常模式

優先規則：
- 讀取最後一筆 success 的 `git_head_commit`
- 若該 commit 仍存在，且是目前 `HEAD` 的祖先
- 則 diff range 固定為 `<git_head_commit>..HEAD`

此時：
- `diff_range_source = last_success_commit`
- `changed_files` 來自 `git diff --name-only "<git_head_commit>..HEAD"`

fallback 規則：
- 若 `git_head_commit` 缺失、已不存在、或不再是 `HEAD` 祖先
- 才回退為時間窗模式

fallback 時：
- `from_time = 最後一筆 success 的 synced_at`
- `to_time = 現在 UTC 時間`
- `changed_files` 來自 `git log --since --until --name-only`
- `diff_range_source = time_window_fallback`

#### 初始化模式

- 使用者必須提供 `from_commit`
- diff range 固定為 `<from_commit>..HEAD`
- `from_time` 取 `from_commit` 的 commit time
- `deleted` 預設不推測

## 4. Candidate Inference 真正做什麼

candidate inference 的目標是找出 impacted endpoints，不是盤點全站文件缺口。

輸入：
- Step 3 的 `changed_files` 與 `diff_range`
- `php -n artisan route:list --json` 的 route snapshot
- Controller / Request / Resource / Service / Exception 的關聯資訊

主要訊號：
- `routes/*` 變更
- controller action diff 命中
- request 變更回推 action
- resource 變更回推 action
- service method 變更回推 action
- exception 變更回推 action 或 service method flow

### `new`、`updated`、`deleted` 的責任邊界

`new`
- 只代表本次 diff 可合理推導為新 route / 新 endpoint mapping 的項目
- 不能只因本地 `openapi.yaml` 缺少該 operation 就成立

`updated`
- 代表既有 endpoint 受本次 controller / request / resource / service / exception 變更影響
- 即使本地 baseline 缺少這支 operation，也仍可輸出 `updated`
- downstream 需以 upsert 方式處理

`deleted`
- 僅在日常模式且存在 baseline 時產出
- 依賴 route snapshot 與 baseline 差集

### baseline 在 candidate inference 的角色

baseline 僅用於：
- diagnostics：顯示目前 OpenAPI 與 route snapshot 的差距
- `deleted` 判定
- 後續 OpenAPI merge

baseline 不應直接用於：
- 把所有 `routeIndex - openapi` 差集直接判成 `new`

這點很重要。若專案本地 `openapi.yaml` 很薄，daily run 仍應只收斂到本次 commit 影響的 endpoints，而不是把歷史文件債全部炸出來。

## 5. Candidate 輸出應包含什麼

`docs/api-docs/candidates/<timestamp>.json` 至少包含：
- `meta`
- `changed_files`
- `candidate_count`
- `candidates`
- `indexes`
- `timings`

`meta` 建議重點閱讀：
- `init_mode`
- `range_source`
- `diff_range_source`
- `diff_range`
- `history_base_commit`
- `range_fallback_reason`
- `last_success_synced_at`
- `baseline_source`
- `has_success_history`
- `has_openapi_baseline`

`indexes` 建議重點閱讀：
- `routes`
- `evaluation_routes`
- `document_route_keys`
- `baseline_gap_route_keys`
- `baseline_deleted_route_keys`

## 6. 使用者確認階段

LLM 必須先與使用者確認候選清單，再進入 OpenAPI 更新。

可調整的內容：
- 移除候選
- 保留候選
- 手動新增候選
- 修正 `new / updated / deleted`

確認完成後，才可產生：
- `docs/api-docs/candidates/<timestamp>.confirmed.json`

未確認前不得修改 `docs/api-docs/openapi.yaml`。

## 7. OpenAPI Merge 階段

`gen-openapi.sh` / PHP generator 的責任是把 confirmed candidates 套回 `docs/api-docs/openapi.yaml`。

處理原則：
- `new`：新增 operation
- `updated`：以 upsert 方式更新 operation
- `deleted`：只在明確允許時刪除或標記 deprecated

這裡 baseline 重新變得重要，因為它是 merge 的既有文件基準。

換句話說：
- candidate inference 不該依賴 baseline 來擴大候選
- 但 OpenAPI merge 必須依賴 baseline 來保留未受影響的既有內容

## 8. Apidog Sync 階段

Apidog sync 只吃本地 `docs/api-docs/openapi.yaml`。

流程要點：
- upload 前先處理 confirmed `updated` 的 conflict compare
- upload 後重新 export 遠端 OpenAPI 驗證結果
- 只有遠端驗證通過，才可 append success history

`missing_remote_endpoint` 的意義：
- 對 confirmed `updated` 而言，代表遠端目前沒有對應 operation
- 這屬於 non-blocking，不應被 `keep_remote` 擋掉

## 9. HTML 產生

Redoc HTML 必須在 Apidog sync 完成後才決定是否產生。

若使用者需要補充文字內容：
- 先討論內容
- 先產出 `docs/api-docs/redoc/extra.md`
- 再執行 `gen-html.sh --with-extra`

HTML 額外內容不得回寫到 `openapi.yaml`。

## 10. 常見異常與判讀方式

### 情境 A：daily run 炸出大量 `new`

常見症狀：
- `candidate_count` 異常大
- `baseline_gap_route_keys` 很高
- `changed_files` 幾乎沒有 API 相關檔案

正確判讀：
- 這通常是 baseline 很薄
- 不代表這次真的新增了大量 API

應檢查：
- `diff_range_source`
- `changed_files`
- `candidate reasons`
- `baseline comparison`

### 情境 B：明明有 success history，卻走 fallback

常見原因：
- `git_head_commit` 缺失
- `git_head_commit` 已不存在
- branch rebase 後 commit 不再是 `HEAD` 祖先

應檢查：
- `meta.history_base_commit`
- `meta.range_fallback_reason`

### 情境 C：本地沒有 operation，但卻被標成 `updated`

這在 commit-driven 模式下是允許的。

原因：
- `updated` 表示本次變更影響到某個 endpoint
- 它不要求本地 baseline 已經有這支 operation
- downstream merge 應以 upsert 處理

## 11. 建議操作原則

1. 日常同步只處理本次 commit 影響的 endpoints。
2. 歷史文件補債應另開治理工作，不要混進 daily guided-sync。
3. baseline 差距要拿來觀測，不要拿來直接當 candidate。
4. 若 history 異常，先修 history 契約，再看 candidate 是否可信。
5. 若發現 `openapi.yaml` 覆蓋率過低，不要期待 daily run 幫你一次補齊全站文件。
