---
name: laravel-api-docs
description: 以 guided-sync 流程自動同步 Laravel API 文件。流程為：AI 先依上次成功同步 commit 推導 Git 變更範圍並推測候選 API 清單，與使用者討論確認後更新 docs/api-docs/openapi.yaml，同步至 Apidog，最後依需求產生 Redoc HTML。當使用者說「幫我產生 API 文件」、「更新 API 文件」、「文件同步」、「sync api docs」時觸發。僅用於 Laravel 專案。
metadata:
  version: "1.0.0"
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
- `docs/api-docs/versions/<version-id>/openapi.yaml`：每次正式 HTML 生成時的 OpenAPI 快照
- `docs/api-docs/versions/<version-id>/redoc/index.html`：每次正式 HTML 生成時的首頁備份
- `docs/api-docs/versions/<version-id>/redoc/api-docs.html`：每次正式 HTML 生成時的純 Redoc 備份
- `docs/api-docs/versions/<version-id>/redoc/extra.md`：本次正式 HTML 生成使用的補充內容快照（僅在啟用補充內容時）
- `docs/api-docs/history/apidog-sync-history.jsonl`：同步歷史
- `docs/api-docs/candidates/<timestamp>.json`：AI 推測候選清單
- `docs/api-docs/candidates/<timestamp>.confirmed.json`：使用者確認後的最終清單
- `docs/api-docs/conflicts/<timestamp>.json`：衝突清單
- `docs/api-docs/reviews/openapi-review.<timestamp>.json`：OpenAPI unresolved review 清單
- `docs/api-docs/reviews/<timestamp>.approved.json`：review decision 清單
- `docs/api-docs/apidog-tree/<timestamp>.json`：本次 Apidog API tree discovery 原始回應
- `docs/api-docs/apidog-tree/<timestamp>.mapping.json`：由 API tree 解析出的 endpoint / prefix -> folderId mapping
- `docs/api-docs/apidog-tree/<timestamp>.decisions.json`：confirmed candidates 的 folderId 決策結果與 unmapped 清單

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
- `docs/api-docs/versions/<version-id>/`（正式 HTML 生成時保存本次 OpenAPI、Redoc HTML 與補充內容快照）

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
- `docs/api-docs/apidog-tree/`
- `docs/api-docs/redoc/`
- `docs/api-docs/versions/`
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
5. 初始化的 `from_commit` 採產品語意上的 inclusive 起點：
- 代表「從這顆 commit 開始算」，必須包含該 commit 本身的修改
- 系統內部會展開為該 commit 的 parent 到 `HEAD` 的 diff range
- `meta.from_commit` 保留使用者輸入，`meta.diff_range` 顯示實際展開結果
- 若指定的是 root commit（沒有 parent），目前直接報錯，要求改用一顆有 parent 的 commit
6. 初始化一律要求使用者確認 `path strategy`：
- `keep-full-path`：保留 `/api/admin/...`
- `strip-api-prefix-to-server`：`paths` 使用 `/admin/...`，由 `servers.url` 承接 `/api`
7. 初始化預設推測 `new + updated`，即使無 OpenAPI 基準也要輸出 `updated` 草案。
8. 初始化預設不自動推測 `deleted`，避免首次導入誤刪歷史 API 文件。

### Step 3：以 commit 範圍為主收斂變更，必要時回退時間窗

1. 時間格式固定使用 UTC ISO 8601：`YYYY-MM-DDTHH:mm:ssZ`（例如 `2026-03-06T16:15:00Z`）。
2. 日常流程：
- 優先讀取最後一筆 `status=success` 的 `git_head_commit`
- 若 `git_head_commit` 存在且仍為目前 `HEAD` 的祖先，diff 範圍固定為 `<git_head_commit>..HEAD`
- 以 `git diff --name-only "<git_head_commit>..HEAD"` 取得變更檔案
- `from_time` 可保留最後一筆 success 的 `synced_at` 作為觀測欄位，`to_time` 為目前 UTC 時間
- 若 `git_head_commit` 缺失、已不存在，或不再是 `HEAD` 祖先，才回退為時間窗模式：
  - `from_time = 最後一筆 success 的 synced_at`
  - `to_time = 現在 UTC 時間`
  - 用 `git log --since="<from_time>" --until="<to_time>" --name-only` 取得變更檔案
3. 初始化流程：
- 使用者輸入的 `from_commit` 代表 inclusive 起點，實際分析範圍會展開為 `<from_commit 的 parent>..HEAD`
- `from_time` 取 `from_commit` 的 commit 時間（轉 UTC ISO 8601）
- `to_time` 取現在 UTC 時間
- 用展開後的 `diff_range` 執行 `git diff --name-only` 取得變更檔案
4. 將 Step 3 結果存成內部分析資料，供 Step 4 推測候選清單。

### Step 4：AI 推測候選 API 清單（先猜）

1. 解析 Step 3 的 commit 變更內容，整理受影響檔案。
2. 以 `php -n artisan route:list --json` 取得目前路由清單，避免本機 PHP extension warning 汙染 JSON。同一條路由若以 `Route::match([...])`／`Route::any()` 註冊多個 HTTP method，route index 必須把每個非 `HEAD`/`OPTIONS` method 各自展開成一筆獨立項目，不得只取第一個，否則其餘 method 會在候選推測與比對階段完全消失。
3. 根據變更來源推測候選 endpoint：
- `routes/*` 變更：高信心候選
- Controller 變更：以 diff 命中的 `Controller@action` 反查 endpoint（避免整個 controller 全入列）；但純 method body diff 只視為弱訊號，不得單獨成立 `updated`
- function 文件註解變更：屬強訊號，包含 description / summary 與可穩定映射到 OpenAPI 的註解，例如 `@queryParam`、`@bodyParam`、`@urlParam`、`@response`、`@responseFile`、`@responseField`
- FormRequest 變更：由 FormRequest -> `Controller@action` -> endpoint（標 `updated`）
- Service 變更：純 method body diff 只視為弱訊號；只有在 diff 內容本身可證明改到 response / error contract（例如 exception flow、error payload、response wrapper）時，才可標 `updated`
- Exception 變更：以 action-scope 判定（Controller action 直接引用，或 action 命中的 service method exception flow 命中）再標 `updated`
- Resource 變更：由 Resource -> `Controller@action` -> endpoint（標 `updated`）
4. 純 service 內部流程、局部變數、repository / query 細節若不影響 request / response / error contract，不得單獨產生 `updated`。
5. 訊號模型：
- 強訊號：route / endpoint mapping、request validation、response metadata、error contract、function 文件註解
- 弱訊號：controller method body diff、service method body diff
- 候選成立規則：強訊號可直接產生 `updated`；弱訊號必須搭配至少一個強訊號，或被解析成明確 contract evidence
6. 日常模式的 `new` / `updated` 只允許來自本次 diff 範圍內的變更訊號；本地 OpenAPI baseline 缺漏只作為 diagnostics，不得直接轉成 candidate。
7. baseline 的角色：
- `new` / `updated` 候選推測：僅供 diagnostics，不直接決定候選
- `deleted` 候選：僅在日常模式且存在 baseline 時，才可由 route / baseline 差集推測
- OpenAPI merge：保留作為既有 operation 的 merge 基準
6. 初始化預設輸出 `new + updated`，且預設不輸出 `deleted`。
7. 產出候選清單到 `docs/api-docs/candidates/<timestamp>.json`，每筆必須包含：
- `status`：`new` | `updated` | `deleted`
- `method`
- `path`
- `change_reason`
- `confidence`：`high` | `medium` | `low`
- `missing_fields`：例如 `request_schema_missing`、`response_schema_missing`
8. `meta` 必須包含：`init_mode`、`baseline_source`、`from_time`、`to_time`、`diff_range_source`、`diff_range`。
9. 若為日常模式，`meta` 應額外揭露：
- `history_base_commit`
- `last_success_synced_at`
- `range_fallback_reason`（若未 fallback 可為 `null`）
10. 將候選清單呈現給使用者。

`--debug` 時建議至少輸出：
- `git change inventory: files / routes / controllers / requests / services / exceptions / resources`
- `baseline comparison: has_openapi_baseline / doc_keys / route_only_keys / openapi_only_keys`
- `action hints: route / controller`
- `candidate signals: service_method_hits / dependency_action_hits / service_action_hints`
- `path strategy: active / source`
- `candidate summary: new / updated / deleted / total`
- `candidate subset: subset / skipped / total_routes`
- `guided-timing: range_selection / class_index / git_inventory / route_snapshot / action_hints / candidate_evaluation / write_output`

補充：
- `baseline comparison` 在所有模式下都應視為 diagnostics；它描述 baseline 缺口，不等於最終候選數。
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
9. confirmed JSON 可額外包含每筆 candidate 的 `folder_id`。若存在，Step 7 folder-aware upload 必須優先使用該值，覆寫自動 mapping。
10. 將確認後的清單落成 `docs/api-docs/candidates/<timestamp>.confirmed.json`。

### Step 6：依最終清單更新 OpenAPI

1. 只針對最終清單做深度分析。
2. 分析每個 endpoint 對應檔案：
- **Controller**：提取 PHPDoc、`@throws`、錯誤訊息、方法說明
- **Service**：分析業務邏輯中的 Exception 與錯誤碼
- **FormRequest / inline validation**：解析 `rules()`、`$request->validate([...])`、`Validator::make(..., [...])` 並轉為 requestBody/schema
- **FormRequest / inline validation**：統一先解析 request fields；body methods 轉為 `requestBody`，GET 等 non-body methods 轉為 OpenAPI `parameters`（`in: query`）
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
6. 若 confirmed 清單中有 method+path 比對不到任何 route（例如 route index 尚未涵蓋、或使用者誤標），`gen-openapi.sh` 必須把這些落單項目明確列成獨立、顯眼的一行警告（`method+path` 清單），不得只藏在 timing 訊息或數字裡。
7. 完成後檢查 YAML 結構合法。
8. `gen-openapi.sh` 現在是 PHP generator 的 thin wrapper；controller / service / FormRequest 解析應在單一 PHP 程序內完成，而不是由 shell parser 作為主路徑。
9. `gen-openapi.sh` 執行中應顯示至少：
- workflow checklist
- 當前 `update_openapi` progress bar
- `guided-timing: route_snapshot / candidate_normalization / endpoint_generation / merge_openapi / apply_deletions / write_output`
10. 若生成過程存在 unresolved request / response / security analysis，必須額外輸出 review artifact，例如：
- `bash "$SKILL_DIR/gen-openapi.sh" --candidate-file docs/api-docs/candidates/<timestamp>.confirmed.json --review-file docs/api-docs/reviews/openapi-review.<timestamp>.json`
11. review artifact 至少要包含：
- `unresolved_validation_rules`
- `unresolved_response_shape`
- `unresolved_security`
- `low_confidence_examples`
12. 若 review artifact 的 `review_item_count > 0`，必須先經使用者/LLM review 後，才能進 Step 7。
13. review decision 可用：
- `bash "$SKILL_DIR/confirm-openapi-review.sh" --input docs/api-docs/reviews/openapi-review.<timestamp>.json --accept-all --output docs/api-docs/reviews/<timestamp>.approved.json`
14. 目前 review decision 的最小契約是：每個 unresolved item 都必須被明確 accept，未被 accept 前不得 upload。
15. `updated` endpoint 的 enrich 目標：
- request input schema 應優先反映常見 Laravel request validation rule，不限於 FormRequest，也包含 controller action 內的 inline validation；至少包含 `nullable`、`string`、`integer`、`numeric`、`boolean`、`array`、`min`、`max`、`between`、`size`、`digits`、`email`、`date`、`in`
- 應支援 Laravel 常見 array-style rules，且不得因 rule 寫法不同而漏掉欄位
- 應將 dotted fields 與 wildcard fields（例如 `profile.name`、`items.*.id`）轉成真正的 nested object / array schema，不得平鋪成原始欄位名
- `Password::min(...)->letters()->numbers()->mixedCase()->symbols()` 應拆成 capability 處理，而不是當成單一 rule 字串
- body methods 的 `requestBody` 與 non-body methods 的 query `parameters` 都應盡量保留 deterministic example、required 與可可靠映射的 schema keyword
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
- 預設啟用 **delta 模式**：只上傳 confirmed candidates（`new` + `updated`）對應的 endpoint，其餘 paths 不進 payload，避免觸碰非本次修改的 API。
- 若使用者要求「完整重建」，加 `--no-delta` 改為全量上傳。
11. **Path strategy alignment check**（自動執行）：取得 remote OpenAPI 後，自動比對本地 `path_strategy` 與遠端實際 path 前綴；不一致時中止上傳並說明差異。
- 使用者可選擇：調整 `path_strategy` 後重新執行，或確認無誤後加 `--skip-alignment-check` 繼續。
- `--skip-alignment-check` 適用於 CI 或已知環境，不建議常態使用。
- 新增 tag（新資料夾）為正常行為，alignment check 不針對 tags 做警告。
12. 若 `keep_remote` 命中 blocking 衝突，實際上傳內容必須保留遠端 operation，不得以本地版本覆蓋。
13. `import-openapi` 回傳 HTTP 200/201 與 counters 不足以單獨視為成功；Step 7 必須在上傳後重新 export 遠端 OpenAPI 驗證結果。
14. 若提供 confirmed candidate file，至少要驗證其中 `new` 與 `updated` endpoint 在遠端 `paths` 中存在；若未提供 candidate file，至少要驗證遠端 export 的 `paths` 非空。
15. post-upload verification 失敗時，整次同步必須視為失敗，不得寫 success history。
16. 若提供 `--review-file` 且 review item count 大於 0，Step 7 必須同時提供 `--review-decision-file`，否則 upload 必須在任何遠端請求前就中止。
17. review decision artifact 必須對應同一份 review artifact，且所有 unresolved item 都要被明確 accept，upload 才可繼續。
18. delta 模式且提供 confirmed candidate file 時，Step 7 預設啟用 folder-aware upload：
- upload 前呼叫 `GET https://api.apidog.com/api/v1/projects/{projectId}/api-tree-list`
- request 必須帶 `Authorization: Bearer <token>` 與 `X-Apidog-Api-Version: 2024-03-28`
- 解析 `apiDetailFolder.<id>` 與 `apiDetail.api.folderId` 建立 mapping
- folderId 決策順序為：candidate `folder_id`、相同 method/path、longest path prefix、明確 root fallback
- 無法 mapping 的 candidates 必須列出；未明確加 `--allow-root-folder-fallback` 前不得靜默丟到 root folder `0`
19. folder-aware delta upload 必須依 resolved folderId 分批 import。每批 payload 只包含該 folder 的 confirmed `new` / `updated` endpoints，且 import request 必須設定：
- `options.targetEndpointFolderId`
- `options.updateFolderOfChangedEndpoint: true`
20. `--no-delta` 或未提供 `--candidate-file` 時，不套用 folder-aware grouping，維持既有 full upload 行為。
21. `api-tree-list` 必須使用 `/api/v1/` 前綴；若收到 redirect 或 permission error，需明確回報原因。若使用者已確認 fallback，可用 `--allow-root-folder-fallback` 將 unmapped candidates 放到 root folder `0`。

### Step 8：詢問是否產生 Redoc HTML

1. 在 Step 7 完成後詢問使用者是否需要產生 HTML 文件。
2. 若使用者選擇「要」，必須先詢問 Redoc 輸出範圍：
- `changed-only`：只產生本次 confirmed `new` / `updated` endpoints
- `full`：使用完整 `docs/api-docs/openapi.yaml`
3. 若使用者選擇「要」，應以使用者語言詢問是否要在 HTML 頁面加入補充說明，例如：
- 文件使用說明
- 認證方式
- 測試環境 / Base URL
- 對接注意事項
4. 不應直接先用 `extra.md` 當成主提問詞；`extra.md` 是內部實作檔案，不是主要使用者概念。
5. 若使用者選擇不要補充內容，流程再以純 HTML 繼續。
6. 若使用者選擇要補充內容，LLM 必須先與使用者討論內容，並為本次生成起草或刷新補充內容。
7. 未完成本次補充內容起草前，不得直接執行 `gen-html.sh --with-extra`。
8. 不得只因 `docs/api-docs/redoc/extra.md` 已存在就沿用舊內容；若要使用既有檔案，必須先向使用者確認它就是本次內容。
9. 若使用者選擇「否」，流程直接結束。
10. 若存在 unresolved review artifact 且尚未完成 review decision，禁止跳過 Step 7 直接進 Step 9。

### Step 9：產生 Redoc HTML

1. 若 Step 8 選擇 `full`，以 `docs/api-docs/openapi.yaml` 固定產出多頁 HTML，並維持最新版固定入口：
- `docs/api-docs/redoc/index.html`
- `docs/api-docs/redoc/api-docs.html`
2. 每次正式 full HTML 生成都必須額外建立版本快照：
- `docs/api-docs/versions/<version-id>/openapi.yaml`
- `docs/api-docs/versions/<version-id>/redoc/index.html`
- `docs/api-docs/versions/<version-id>/redoc/api-docs.html`
- 若啟用補充內容，額外保存 `docs/api-docs/versions/<version-id>/redoc/extra.md`
3. `<version-id>` 使用本機時間 `YYYYMMDD-HHMMSS`，若同名資料夾已存在則加遞增後綴，避免覆蓋舊備份。
4. `index.html` 是正式分享入口，承接同步摘要、補充說明與導覽；`docs/api-docs/redoc/` 永遠代表最新版。
5. `api-docs.html` 必須保持為純 Redoc API 文件頁，不再把補充內容與 Redoc 混在同一頁。
6. 依 Step 8 選項決定是否載入本次補充內容到 `index.html`。
7. 若使用者在 Step 8 選擇補充內容，應先由 LLM 起草或刷新本次 markdown，再進行 HTML 生成；可寫入 `docs/api-docs/redoc/extra.md` 作為最新版草稿，或用 `--extra-file <current-run-file>` 指定本次檔案。
8. 額外內容不得修改 OpenAPI；正式版本生成時，`gen-html.sh` 會把本次使用的 extra markdown 快照保存到版本資料夾。
9. `gen-html.sh` 可使用：
- `bash "$SKILL_DIR/gen-html.sh" --openapi docs/api-docs/openapi.yaml --with-extra`
10. 若使用者要求載入額外內容但本次內容尚未起草，流程不應直接詢問「檔案不存在」；應先回到 Step 8 的內容討論與起草。
11. 僅在使用者已明確選擇不加補充內容時，才能執行不帶額外內容的生成；此時即使舊 `docs/api-docs/redoc/extra.md` 存在也不得載入。
12. 即使沒有補充內容，`index.html` 仍應被產出為固定首頁，提供一致的分享入口與導覽。
13. 若使用自訂 `--output` 產生臨時 HTML，該輸出不建立 `docs/api-docs/versions/` 正式版本快照。
14. 若 Step 8 選擇 `changed-only`，必須先產生 subset OpenAPI：
- `bash "$SKILL_DIR/gen-subset-openapi.sh" --openapi docs/api-docs/openapi.yaml --candidate-file docs/api-docs/candidates/<timestamp>.confirmed.json --output docs/api-docs/versions/<version-id>/subset-openapi.json`
15. changed-only Redoc 必須以 subset OpenAPI 呼叫 `gen-html.sh --openapi <subset>`，預設輸出到 `docs/api-docs/versions/<version-id>/subset-redoc/api-docs.html`，不得覆蓋 `docs/api-docs/redoc/index.html` 或 `docs/api-docs/redoc/api-docs.html`，除非使用者明確確認替換正式入口。
16. changed-only subset 只包含 confirmed `new` / `updated` endpoints；`deleted` candidates 不進 subset Redoc。

## 同步歷史紀錄規格

檔案：`docs/api-docs/history/apidog-sync-history.jsonl`

每行一筆 compact JSON，欄位：
- `schema_version`：本筆紀錄的欄位結構版本（目前為 `1`）
- `sync_id`：唯一識別碼
- `synced_at`：ISO 8601 時間（後續 Step 3 日常流程的基準）
- `from_time`：本次推測起始時間
- `to_time`：本次推測結束時間
- `git_head_commit`：同步當下 HEAD commit
- `git_branch`：同步當下分支
- `path_strategy`：專案採用的 path 表示策略
- `openapi_sha256`：`docs/api-docs/openapi.yaml` 雜湊
- `apidog_project_id`：目標 Apidog 專案 ID
- `imported_count`：新增數量
- `updated_count`：更新數量
- `skipped_count`：略過數量
- `conflict_count`：衝突數量
- `status`：`success` | `failed`

範例：

```json
{"schema_version":1,"sync_id":"20260306T161500Z-a1b2c3","synced_at":"2026-03-06T16:15:00Z","from_time":"2026-03-05T10:20:00Z","to_time":"2026-03-06T16:15:00Z","git_head_commit":"a1b2c3d4","git_branch":"main","path_strategy":"strip-api-prefix-to-server","openapi_sha256":"...","apidog_project_id":"123456","imported_count":8,"updated_count":3,"skipped_count":21,"conflict_count":1,"status":"success"}
```

規則：
- Step 3 日常流程優先使用最後一筆 `status=success` 的 `git_head_commit` 當 commit baseline。
- 日常與 generator 優先沿用最後一筆 success 的 `path_strategy`；若 legacy history 缺少該欄位，才回退偵測或舊預設。
- 若 `git_head_commit` 缺失、不可用或不再是 `HEAD` 祖先，才回退使用最後一筆 success 的 `synced_at`。
- `schema_version` 缺失的舊紀錄視為隱含版本 1，比照 `path_strategy` 的容錯精神：缺少新欄位時回退偵測或舊預設，不強制要求既有歷史紀錄補齊欄位或遷移。未來新增/改名欄位時，應評估是否需要遞增 `schema_version`。
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

---

## Cherry-pick 模式

### 觸發條件

當使用者說以下任何一種時，進入 cherry-pick 模式，**不走完整 guided-sync 流程**：
- 「我只想上傳這幾個 API」
- 「單獨產這幾個 endpoint 的 Redoc」
- 「cherry-pick」、「挑幾個 API」、「只針對 xxx API」

> 「幫我產生 API 文件」、「更新 API 文件」、「文件同步」仍進入 guided-sync 主流程。

### 點名特定 API 時的模式判斷（避免來回確認）

cherry-pick 只會從既有 `docs/api-docs/openapi.yaml` 挑選、重新上傳或重新產生 Redoc，**不會重新分析 Laravel 原始碼**。當使用者的話點名了一個或少數幾個具體 API/endpoint（而不是「全部」、「所有 API」這類全面性字眼），但沒有明確用到上面的 cherry-pick 觸發詞，這句話本身無法判斷使用者是要：

- (a) 那支 API 的程式碼是新寫或剛改過，需要重新分析原始碼 → 屬於 guided-sync，但可以把分析範圍口頭確認為「只針對這支 API」
- (b) 那支 API 程式碼沒變，只是要重新上傳/重新產生既有 spec 裡已經有的文件 → 屬於 cherry-pick

LLM **必須在執行任何腳本前**，用一句話直接問清楚是 (a) 還是 (b)，不得先假設走 guided-sync 主流程、等使用者跑完/看到結果才發現不是他要的。判斷用的問句範例：「這支 API 的程式碼是不是剛寫/改過？如果是，我會照 guided-sync 分析，但只針對這支；如果程式碼沒變、只是要重新出文件，我會走 cherry-pick，直接從既有 spec 挑出來。」

### 流程

1. **列出現有 endpoint 清單**
   - LLM 讀取 `docs/api-docs/openapi.yaml`，列出所有 `method + path + summary`（每行一筆）。

2. **使用者選取 endpoint**
   - 支援明確列舉：`GET /users`、`POST /orders`
   - 支援描述式：「跟付款相關的 API」→ LLM 依 tag / path / summary 推薦候選，使用者確認後才繼續
   - 每次調整後回顯目前選定清單，直到使用者明確確認

3. **組出 temp subset spec**
   - LLM 從 `openapi.yaml` 複製選定的 paths，保留完整 `info`、`servers`、`components`、`tags`
   - 寫入 `/tmp/cherry-pick-<timestamp>.json`
   - **嚴禁修改或覆蓋 `docs/api-docs/openapi.yaml`**

4. **選擇動作**（可複選）
   - **上傳 Apidog**：
     ```bash
     bash "$SKILL_DIR/upload-apidog.sh" \
       --openapi /tmp/cherry-pick-<timestamp>.json \
       --skip-history \
       --no-delta
     ```
     - `--skip-history`：不寫 sync history，不影響 guided-sync 的 Step 3 baseline
     - `--no-delta`：subset spec 本身就是要全數上傳的內容，不再過濾
     - 上傳前 LLM **必須**告知使用者：「本次跳過 conflict detection，若遠端有手動修改將被覆蓋，確認繼續？」
   - **產 Redoc HTML**：
     ```bash
     bash "$SKILL_DIR/gen-html.sh" \
       --openapi /tmp/cherry-pick-<timestamp>.json
     ```
     - 輸出位置由使用者指定，或預設寫到 `/tmp/cherry-pick-redoc-<timestamp>.html`
     - **不覆蓋** `docs/api-docs/redoc/` 下的正式檔案

### 限制

- cherry-pick 不更新 `docs/api-docs/openapi.yaml`
- cherry-pick 不寫 `apidog-sync-history.jsonl`
- cherry-pick 上傳不執行 conflict detection（快速通道，使用者需自行確認）
- cherry-pick 不執行 path strategy alignment check（已知 subset，使用者自行負責）
