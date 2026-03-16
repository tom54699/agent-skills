---
name: laravel-api-docs
description: 以 guided-sync 流程自動同步 Laravel API 文件。流程為：AI 先依上次成功同步時間切出 Git 變更範圍並推測候選 API 清單，與使用者討論確認後更新 docs/api-docs/openapi.yaml，同步至 Apidog，最後依需求產生 Redoc HTML。當使用者說「幫我產生 API 文件」、「更新 API 文件」、「文件同步」、「sync api docs」時觸發。僅用於 Laravel 專案。
---

# Laravel API 文件同步（guided-sync）

使用單一模式 `guided-sync` 完成 API 文件流程。

## 核心原則

1. AI 先推測候選 API 清單，再與使用者討論修正。
2. `docs/api-docs/openapi.yaml` 是同步 Apidog 的唯一來源。
3. 同步順序固定：更新 OpenAPI -> 同步 Apidog（含衝突處理）-> 視需求產生 HTML。
4. HTML 額外內容不回寫 OpenAPI。
5. 每次成功同步後都必須寫入歷史紀錄。
6. guided-sync 執行時預設輸出整體步驟 checklist、目前步驟 progress bar、以及主要階段 timing 行到 `stderr`。

## 目錄慣例

- `docs/api-docs/openapi.yaml`：OpenAPI 規格主檔
- `docs/api-docs/redoc/index.html`：HTML 首頁／同步摘要入口
- `docs/api-docs/redoc/api-docs.html`：純 Redoc API 文件頁
- `docs/api-docs/redoc/extra.md`：HTML 額外內容（可選）
- `docs/api-docs/history/apidog-sync-history.jsonl`：同步歷史
- `docs/api-docs/candidates/<timestamp>.json`：AI 推測候選清單
- `docs/api-docs/candidates/<timestamp>.confirmed.json`：使用者確認後的最終清單
- `docs/api-docs/conflicts/<timestamp>.json`：衝突清單
- `docs/api-docs/reviews/openapi-review.<timestamp>.json`：OpenAPI unresolved review 清單
- `docs/api-docs/reviews/<timestamp>.approved.json`：review decision 清單

## 輸入與輸出

輸入：
- Laravel 專案原始碼（`routes/`、Controller、FormRequest、Resource、Service、Exception）
- `docs/api-docs/openapi.yaml`（若已存在）
- `docs/api-docs/history/apidog-sync-history.jsonl`（若已存在）

輸出：
- `docs/api-docs/openapi.yaml`
- `docs/api-docs/history/apidog-sync-history.jsonl`（成功時 append 一筆）
- `docs/api-docs/redoc/index.html`（僅在選擇產生 HTML 時）
- `docs/api-docs/redoc/api-docs.html`（僅在選擇產生 HTML 時）

## 分析模式（成本）

- `fast`（預設）：只做結構化快速推測，不做深層語意補強，適合日常更新與初始化。
- `enhanced`：在 `fast` 基礎上增加 Controller/FormRequest/Service/Exception 關聯訊號，適合候選清單仍不夠準時。

## 執行流程

補充：
- 各腳本的結構化 JSON 結果仍走 `stdout`。
- 進度與 timing 只走 `stderr`，不應污染 JSON。
- 若需安靜模式，可使用 `--no-progress` 關閉進度輸出。

### Step 1：Preflight

1. 先執行：
- `bash "$SKILL_DIR/preflight.sh"`
2. `preflight.sh` 必須負責檢查 Laravel 專案根目錄存在 `artisan` 與 `routes/`。
3. `preflight.sh` 必須負責檢查 `.env.agents` 內有：
- `APIDOG_ACCESS_TOKEN`
- `APIDOG_PROJECT_ID`
4. 若 `.env.agents` 缺少上述欄位，流程必須中止，要求使用者提供後再繼續。
5. `preflight.sh` 必須負責檢查 `.gitignore` 已包含 `.env.agents`。
6. `preflight.sh` 必須負責建立必要目錄：
- `docs/api-docs/`
- `docs/api-docs/history/`
- `docs/api-docs/candidates/`
- `docs/api-docs/conflicts/`
- `docs/api-docs/reviews/`
- `docs/api-docs/redoc/`
7. `preflight.sh` 必須檢查 `jq`、`yq`、`php` 等必要工具。
8. `preflight.sh` 必須驗證 `php -n` 可執行，且 `php -n artisan route:list --json` 可成功產出合法 JSON。
9. 只有 `preflight.sh` 成功後，才能進入候選推測。

若 preflight 失敗，立即中止並回覆錯誤訊息。

### Step 2：判斷基準來源與初始化分流

1. 讀取 `docs/api-docs/history/apidog-sync-history.jsonl` 最後一筆 `status=success`。
2. 若存在 success history，走日常流程。
3. 若不存在 success history，進入初始化分流並與使用者確認基準來源（三選一）：
- 本地 OpenAPI（`docs/api-docs/openapi.yaml`）
- 從 Apidog 匯出後落地為 `docs/api-docs/openapi.yaml`
- 無基準（只追蹤未來新增 API，不回補舊 API）
4. 初始化（無 success history）一律要求使用者提供 `from_commit`，並驗證 commit 存在且為 `HEAD` 祖先。
5. 初始化預設推測 `new + updated`，即使無 OpenAPI 基準也要輸出 `updated` 草案。
6. 初始化預設不自動推測 `deleted`，避免首次導入誤刪歷史 API 文件。

### Step 3：以時間與 commit 範圍收斂變更

1. 時間格式固定使用 UTC ISO 8601：`YYYY-MM-DDTHH:mm:ssZ`（例如 `2026-03-06T16:15:00Z`）。
2. 日常流程：
- `from_time = 最後一筆 success 的 synced_at`
- `to_time = 現在 UTC 時間`
- 用 `git log --since="<from_time>" --until="<to_time>" --name-only` 取得變更檔案
3. 初始化流程：
- commit 範圍固定為 `<from_commit>..HEAD`
- `from_time` 取 `from_commit` 的 commit 時間（轉 UTC ISO 8601）
- `to_time` 取現在 UTC 時間
- 用 `git diff --name-only "<from_commit>..HEAD"` 取得變更檔案
4. 將 Step 3 結果存成內部分析資料，供 Step 4 推測候選清單。

### Step 4：AI 推測候選 API 清單（先猜）

1. 解析 Step 3 的 commit 變更內容，整理受影響檔案。
2. 以 `php -n artisan route:list --json` 取得目前路由清單，避免本機 PHP extension warning 汙染 JSON。
3. 根據變更來源推測候選 endpoint：
- `routes/*` 變更：高信心候選
- Controller 變更：以 diff 命中的 `Controller@action` 反查 endpoint（避免整個 controller 全入列）
- FormRequest 變更：由 FormRequest -> `Controller@action` -> endpoint（標 `updated`）
- Service 變更：必須先抽出 `Service::method` 變更，再由 `Service::method -> Controller@action -> endpoint`（標 `updated`）
- Exception 變更：以 action-scope 判定（Controller action 直接引用，或 action 命中的 service method exception flow 命中）再標 `updated`
- Resource 變更：由 Resource -> `Controller@action` -> endpoint（標 `updated`）
4. 初始化預設輸出 `new + updated`，且預設不輸出 `deleted`。
5. 產出候選清單到 `docs/api-docs/candidates/<timestamp>.json`，每筆必須包含：
- `status`：`new` | `updated` | `deleted`
- `method`
- `path`
- `change_reason`
- `confidence`：`high` | `medium` | `low`
- `missing_fields`：例如 `request_schema_missing`、`response_schema_missing`
6. `meta` 必須包含：`init_mode`、`baseline_source`、`from_time`、`to_time`、`diff_range_source`、`diff_range`。
7. 將候選清單呈現給使用者。

`--debug` 時建議至少輸出：
- `git change inventory: files / routes / controllers / requests / services / exceptions / resources`
- `baseline comparison: has_openapi_baseline / doc_keys / route_only_keys / openapi_only_keys`
- `action hints: route / controller`
- `candidate signals: service_method_hits / dependency_action_hits / service_action_hints`
- `candidate summary: new / updated / deleted / total`
- `candidate subset: subset / skipped / total_routes`
- `guided-timing: range_selection / class_index / git_inventory / route_snapshot / action_hints / candidate_evaluation / write_output`

補充：
- `baseline comparison` 在 `has_openapi_baseline=false` 時僅供參考，不代表最終候選數。
- 初始化模式應優先閱讀 `action hints`、`prefilter summary`、`candidate summary` 來判斷收斂效果。
- 若啟用新版可觀測性，`candidate_subset` 代表真正進入深度 evaluation 的 route 工作集；`candidate_evaluation` 不應再直接掃整份 route snapshot。
- `infer-candidates.sh` 現在是 PHP analyzer 的 thin wrapper；舊 shell-heavy inference 已移除。

### Step 5：與使用者討論並確認最終清單

1. 預設只向使用者展示精簡清單：`status / method / path`。
2. 若使用者需要再補充 `change_reason`、`confidence` 或 `signals`。
3. 這一步由 LLM 主導互動，shell script 不直接負責多輪對話。
4. LLM 必須維護一份 working list，支援使用者：
- 移除候選
- 保留候選
- 手動新增 API
- 調整 `new / updated / deleted`
5. 每次調整後都要回顯最新工作清單，直到使用者明確確認。
6. 使用者未確認前，不得更新 `docs/api-docs/openapi.yaml`。
7. 使用者確認後，LLM 必須先把 working list 寫成 JSON，再用：
- `bash "$SKILL_DIR/confirm-candidates.sh" --input <working-list.json> --output docs/api-docs/candidates/<timestamp>.confirmed.json`
8. confirmed JSON 至少只需包含：
- `status`
- `method`
- `path`
9. 將確認後的清單落成 `docs/api-docs/candidates/<timestamp>.confirmed.json`。

### Step 6：依最終清單更新 OpenAPI

1. 只針對最終清單做深度分析。
2. 分析每個 endpoint 對應檔案：
- **Controller**：提取 PHPDoc、`@throws`、錯誤訊息、方法說明
- **Service**：分析業務邏輯中的 Exception 與錯誤碼
- **FormRequest / inline validation**：解析 `rules()`、`$request->validate([...])`、`Validator::make(..., [...])` 並轉為 requestBody/schema
- **Exception**：解析自訂 Exception 的預設錯誤訊息與 HTTP 狀態碼
- **Resource（可選）**：解析回應欄位結構
3. 依分析結果更新 `docs/api-docs/openapi.yaml`：
- `new`：新增 endpoint
- `updated`：更新 endpoint 定義
- `deleted`：預設不自動刪除，先輸出待確認清單；經使用者確認後才刪除或標記為 `deprecated`
4. 更新入口必須以 confirmed JSON 為輸入，例如：
- `bash "$SKILL_DIR/confirm-candidates.sh" --input <working-list.json> --output docs/api-docs/candidates/<timestamp>.confirmed.json`
- `bash "$SKILL_DIR/gen-openapi.sh" --candidate-file docs/api-docs/candidates/<timestamp>.confirmed.json --incremental`
5. 若 `confirmed.json` 內只有 `deleted` 項目，仍必須允許更新既有 OpenAPI 並套用刪除。
6. 完成後檢查 YAML 結構合法。
7. `gen-openapi.sh` 現在是 PHP generator 的 thin wrapper；controller / service / FormRequest 解析應在單一 PHP 程序內完成，而不是由 shell parser 作為主路徑。
8. `gen-openapi.sh` 執行中應顯示至少：
- workflow checklist
- 當前 `update_openapi` progress bar
- `guided-timing: route_snapshot / candidate_normalization / endpoint_generation / merge_openapi / apply_deletions / write_output`
9. 若生成過程存在 unresolved request / response / security analysis，必須額外輸出 review artifact，例如：
- `bash "$SKILL_DIR/gen-openapi.sh" --candidate-file docs/api-docs/candidates/<timestamp>.confirmed.json --review-file docs/api-docs/reviews/openapi-review.<timestamp>.json`
10. review artifact 至少要包含：
- `unresolved_validation_rules`
- `unresolved_response_shape`
- `unresolved_security`
- `low_confidence_examples`
11. 若 review artifact 的 `review_item_count > 0`，必須先經使用者/LLM review 後，才能進 Step 7。
12. review decision 可用：
- `bash "$SKILL_DIR/confirm-openapi-review.sh" --input docs/api-docs/reviews/openapi-review.<timestamp>.json --accept-all --output docs/api-docs/reviews/<timestamp>.approved.json`
13. 目前 review decision 的最小契約是：每個 unresolved item 都必須被明確 accept，未被 accept 前不得 upload。
14. `updated` endpoint 的 enrich 目標：
- requestBody schema 應優先反映常見 Laravel request validation rule，不限於 FormRequest，也包含 controller action 內的 inline validation；至少包含 `nullable`、`string`、`integer`、`numeric`、`boolean`、`array`、`min`、`max`、`between`、`size`、`digits`、`email`、`date`、`in`
- 應支援 Laravel 常見 array-style rules，且不得因 rule 寫法不同而漏掉欄位
- 應將 dotted fields 與 wildcard fields（例如 `profile.name`、`items.*.id`）轉成真正的 nested object / array schema，不得平鋪成原始欄位名
- `Password::min(...)->letters()->numbers()->mixedCase()->symbols()` 應拆成 capability 處理，而不是當成單一 rule 字串
- requestBody 應產生 deterministic example，至少覆蓋 scalar、enum、array 欄位
- 無法可靠映射的 request rules（例如 `exists`、`unique`、`required_if`）應保留 unresolved 訊號，例如 `x-laravel-unresolved-rules`，不得直接靜默丟棄
- responses 應優先補 success example、validation error example、以及 controller / service / exception 可收斂出的錯誤訊號
- responses 應先分析 controller 實際 return 形式，例如 `response()->json(...)`、`new JsonResponse(...)`、array literal、`JsonResource`、`Resource::collection(...)`
- 專案自訂 wrapper（例如 `response()->apiResponse(...)`）應走 project-specific response adapter，不得寫死為 Laravel 通用規則
- 若專案 adapter 可可靠解析 success / error envelope，response schema 與 example 應反映完整 envelope，而不是只剩 `data`
- success response 應優先採用 controller `apiResponse()` 可可靠解析出的 data payload；只有在 payload 無法解析時才回退 path-based heuristic
- bearer token `security` 應由 route middleware 決定，優先標在 operation level，不應對所有 API 全域套用
- 若缺少可靠訊號，仍應保守回退到 generic response schema，不得捏造過度細節

### Step 7：同步到 Apidog 並處理衝突

1. 使用 `docs/api-docs/openapi.yaml` 同步至 Apidog。
2. 對 `updated` 項目執行衝突判斷，衝突輸出到 `docs/api-docs/conflicts/<timestamp>.json`。
3. 衝突清單每筆至少包含：`method`、`path`、`conflict_type`、`reason`、`suggested_action`。
4. `updated` 衝突判斷欄位至少包含：
- `summary`
- `description`
- `parameters`（name/in/path/required/schema）
- `requestBody`（content/schema）
- `responses`（status code/content/schema）
- `tags`
5. `updated` 衝突處理規則：
- `keep_remote`：保留 Apidog 現況（預設）
- `use_local`：以本地 OpenAPI 覆蓋
- `manual_merge`：人工調整後再同步
6. 未被明確確認的衝突一律採 `keep_remote`。
7. 若 `conflict_type = missing_remote_endpoint`，表示本地 confirmed `updated` endpoint 在遠端不存在對應 operation；這類結果應視為 non-blocking，允許本地 operation 進 upload payload，不得被 `keep_remote` 移除。
8. 同步成功後 append 歷史紀錄到 `docs/api-docs/history/apidog-sync-history.jsonl`。
9. 若同步失敗，保留本地檔案並回報錯誤，不寫成功歷史。
10. `upload-apidog.sh` 應以 confirmed candidate file 中的 `updated` 項目作為 conflict compare 範圍，例如：
- `bash "$SKILL_DIR/upload-apidog.sh" --openapi docs/api-docs/openapi.yaml --candidate-file docs/api-docs/candidates/<timestamp>.confirmed.json`
11. 若 `keep_remote` 命中 blocking 衝突，實際上傳內容必須保留遠端 operation，不得以本地版本覆蓋。
12. `import-openapi` 回傳 HTTP 200/201 與 counters 不足以單獨視為成功；Step 7 必須在上傳後重新 export 遠端 OpenAPI 驗證結果。
13. 若提供 confirmed candidate file，至少要驗證其中 `new` 與 `updated` endpoint 在遠端 `paths` 中存在；若未提供 candidate file，至少要驗證遠端 export 的 `paths` 非空。
14. post-upload verification 失敗時，整次同步必須視為失敗，不得寫 success history。
15. 若提供 `--review-file` 且 review item count 大於 0，Step 7 必須同時提供 `--review-decision-file`，否則 upload 必須在任何遠端請求前就中止。
16. review decision artifact 必須對應同一份 review artifact，且所有 unresolved item 都要被明確 accept，upload 才可繼續。

### Step 8：詢問是否產生 Redoc HTML

1. 在 Step 7 完成後詢問使用者是否需要產生 HTML 文件。
2. 若使用者選擇「要」，應以使用者語言詢問是否要在 HTML 頁面加入補充說明，例如：
- 文件使用說明
- 認證方式
- 測試環境 / Base URL
- 對接注意事項
3. 不應直接先用 `extra.md` 當成主提問詞；`extra.md` 是內部實作檔案，不是主要使用者概念。
4. 若使用者選擇不要補充內容，流程再以純 HTML 繼續。
5. 若使用者選擇要補充內容，LLM 必須先與使用者討論內容，並起草 `docs/api-docs/redoc/extra.md`。
6. 未完成 `extra.md` 起草前，不得直接執行 `gen-html.sh --with-extra`。
7. 若使用者選擇「否」，流程直接結束。
8. 若存在 unresolved review artifact 且尚未完成 review decision，禁止跳過 Step 7 直接進 Step 9。

### Step 9：產生 Redoc HTML（同一份 OpenAPI）

1. 以 `docs/api-docs/openapi.yaml` 固定產出多頁 HTML：
- `docs/api-docs/redoc/index.html`
- `docs/api-docs/redoc/api-docs.html`
2. `index.html` 是正式分享入口，承接同步摘要、補充說明與導覽。
3. `api-docs.html` 必須保持為純 Redoc API 文件頁，不再把補充內容與 Redoc 混在同一頁。
4. 依 Step 8 選項決定是否載入 `docs/api-docs/redoc/extra.md` 到 `index.html`。
5. 若使用者在 Step 8 選擇補充內容，應先由 LLM 起草 `docs/api-docs/redoc/extra.md`，再進行 HTML 生成。
6. 額外內容只放在 `docs/api-docs/redoc/extra.md`，不修改 OpenAPI。
7. `gen-html.sh` 可使用：
- `bash "$SKILL_DIR/gen-html.sh" --openapi docs/api-docs/openapi.yaml --with-extra`
8. 若使用者要求載入額外內容但 `extra.md` 尚不存在，流程不應直接詢問「檔案不存在」；應先回到 Step 8 的內容討論與起草。
9. 僅在使用者已明確選擇純 HTML 時，才能執行不帶額外內容的生成。
10. 即使沒有補充內容，`index.html` 仍應被產出為固定首頁，提供一致的分享入口與導覽。

## 同步歷史紀錄規格

檔案：`docs/api-docs/history/apidog-sync-history.jsonl`

每行一筆 JSON，欄位：
- `sync_id`：唯一識別碼
- `synced_at`：ISO 8601 時間（後續 Step 3 日常流程的基準）
- `from_time`：本次推測起始時間
- `to_time`：本次推測結束時間
- `git_head_commit`：同步當下 HEAD commit
- `git_branch`：同步當下分支
- `openapi_sha256`：`docs/api-docs/openapi.yaml` 雜湊
- `apidog_project_id`：目標 Apidog 專案 ID
- `imported_count`：新增數量
- `updated_count`：更新數量
- `skipped_count`：略過數量
- `conflict_count`：衝突數量
- `status`：`success` | `failed`

範例：

```json
{"sync_id":"20260306T161500Z-a1b2c3","synced_at":"2026-03-06T16:15:00Z","from_time":"2026-03-05T10:20:00Z","to_time":"2026-03-06T16:15:00Z","git_head_commit":"a1b2c3d4","git_branch":"main","openapi_sha256":"...","apidog_project_id":"123456","imported_count":8,"updated_count":3,"skipped_count":21,"conflict_count":1,"status":"success"}
```

規則：
- Step 3 日常流程只使用最後一筆 `status=success` 的 `synced_at` 當基準。
- 上傳失敗可記 `failed`，但不可覆蓋成功基準。

## 錯誤處理

### 非 Laravel 專案

立即中止：

```text
錯誤：此目錄不是 Laravel 專案
需要 artisan 檔案與 routes/ 目錄。
```

### 缺少 Apidog 設定

中止並要求補齊：

```text
錯誤：缺少 APIDOG_ACCESS_TOKEN 或 APIDOG_PROJECT_ID
請提供後寫入 .env.agents。
```

### PHP 執行環境不符合主路徑需求

立即中止：

```text
錯誤：找不到 php，或 php -n 無法執行，或 php -n artisan route:list --json 輸出不合法
guided-sync 目前以 PHP analyzer / generator 為主路徑，請先修正 PHP 執行環境。
```

### Apidog 同步失敗

回覆錯誤與排查重點，不中斷本地輸出：
- token 是否有效
- project id 是否正確
- 網路是否正常

### 無可更新 endpoint

回覆：

```text
本次候選清單經確認後無需變更，已略過 OpenAPI 與 Apidog 更新。
```

## 注意事項

1. 若使用者明確要求「完整重建」，可在 `guided-sync` 內採全量更新策略。
2. 候選清單永遠是草案；最終以使用者確認清單為準。
3. Redoc 用於閱讀；Apidog 用於協作與測試，兩者來源都必須對齊同一版 OpenAPI。
