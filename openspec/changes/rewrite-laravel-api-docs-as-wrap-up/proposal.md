## Why

最近四次收尾都沒有走 guided-sync，而是用同一套手寫流程完成。PHP 產生器以 regex 解析 Laravel 原始碼，追不到 service 呼叫鏈、Transformer 與 exception handler 定義的錯誤碼，草稿每次都要大改；「`openapi.yaml` 是唯一來源」也已和實況脫節（有 API 只存在 Apidog）。使用者決定把這個 skill 改成只服務自己的「開發完成後收尾」流程：由 AI 直接撰寫 OpenAPI、上傳 Apidog、產出以業務邏輯為主的 Redoc 文件，並起草 Jira 單。

## What Changes

- **BREAKING** 移除 guided-sync 與 cherry-pick 模式：候選推測、PHP OpenAPI 產生器、OpenAPI review loop、衝突偵測、同步歷史、path strategy、初始化分流、`docs/api-docs/openapi.yaml` 主檔維護全部移除。
- **BREAKING** 刪除 `src/`、`bin/infer-candidates.php`、`bin/gen-openapi.php`、guided-sync 專用 scripts 與 `tests/laravel_api_docs_*.php`。
- 新流程（skill 名稱與位置不變）：確認範圍 → AI 撰寫 OpenAPI → 使用者確認 → 上傳 Apidog 並驗證 → 產生 Redoc → 起草 Jira 單。
- 每次執行輸出一個獨立資料夾 `docs/api-docs/<YYYYMMDD>-<topic>/`，只處理本次確認範圍內的 API，不維護過去的輸出。
- 範圍內已存在於 Apidog 的 API：先匯出遠端版本（含 Apidog extensions）當底，只改有變動的部分，保留自訂 header 與 `x-apidog-status`。
- 專案慣例（header、security、錯誤碼範本、命名、description 寫法）放在 Laravel 專案的 `docs/api-docs/conventions.md`，由 AI 讀取；不寫進本 repo。首次使用時由 AI 從既有 endpoint 的遠端匯出起草，使用者確認後存檔。
- 新增 `export-remote.sh`（帶 extensions 匯出指定 API）與 `list-folders.sh`（列出資料夾路徑與 ID）。
- `upload-apidog.sh` 精簡為：依資料夾分批上傳本次 spec；指定 folder_id 時自動移除 `x-apidog-folder`；上傳後驗證 API 存在且位於預期資料夾。
- `gen-html.sh` 精簡為：輸入本次 spec 與業務邏輯 markdown，輸出 `index.html` 與 `api-docs.html` 到本次資料夾。`index.html` 必定產生，固定章節為「目的、需求、業務邏輯、前端要改什麼」。
- Jira：AI 依開發內容起草前端或後端單，不確定的地方標 TODO；使用者確認後才建立。skill 不內建 Jira 整合，建立時使用當下可用的工具。
- 同步更新 repo 文件與索引：`CLAUDE.md`、`AGENTS.md`、`README.md`、`docs/install-skills.md`；刪除 `docs/laravel-api-docs-guided-sync.md`；修正 `.ai-project-index/config.json` 與 `ai-project-index` scripts 中指向已刪檔案的路徑。

## Capabilities

### New Capabilities
- `laravel-api-docs-wrap-up-workflow`：開發收尾流程本體，包含範圍確認、專案慣例檔、AI 撰寫 OpenAPI（新增／以遠端為底更新）、上傳前確認、輸出資料夾、Redoc 首頁固定章節、Jira 草稿與建立前確認。
- `laravel-api-docs-apidog-tools`：Apidog 操作腳本，包含帶 extensions 的遠端匯出、資料夾清單、依資料夾分批上傳與 `x-apidog-folder` 防呆、上傳後的路徑與資料夾驗證。

### Modified Capabilities
（無）

### Removed Capabilities
以下既有 capability 描述的是 guided-sync / cherry-pick / PHP 產生器行為，本次整個移除。OpenSpec 不允許以 REMOVED delta 把 spec 移除到沒有 requirement（archive 會中止），因此在實作階段直接刪除 `openspec/specs/<name>/`，由 git 歷史保留：
- `laravel-api-docs-guided-sync`、`laravel-api-docs-bootstrap-initialization`、`laravel-api-docs-initialization-updated-inference`、`laravel-api-docs-range-selection`、`laravel-api-docs-sync-history-commit-baseline`、`laravel-api-docs-preflight-automation`、`laravel-api-docs-runtime-readiness`、`laravel-api-docs-progress-observability`
- `laravel-api-docs-candidate-debug-clarity`、`laravel-api-docs-candidate-evaluation-performance`、`laravel-api-docs-candidate-inference-precision`、`laravel-api-docs-candidate-output-reliability`、`laravel-api-docs-commit-driven-candidate-inference`、`laravel-api-docs-contract-surface-candidate-inference`、`laravel-api-docs-php-candidate-analyzer`、`laravel-api-docs-multi-method-route-indexing`
- `laravel-api-docs-php-openapi-generator`、`laravel-api-docs-openapi-review-loop`、`laravel-api-docs-path-strategy`、`laravel-openapi-query-parameter-generation`、`laravel-openapi-request-schema-normalization`、`laravel-openapi-request-validation-enrichment`、`laravel-openapi-response-example-enrichment`、`laravel-openapi-response-return-analysis`
- `laravel-api-docs-apidog-conflict-sync`、`apidog-folder-aware-upload`、`apidog-path-strategy-alignment`、`delta-upload`、`cherry-pick-mode`
- `laravel-api-docs-output-versioning`、`laravel-api-docs-html-extra-prompting`、`laravel-api-docs-redoc-extra-content`

## Impact

- `skills/laravel-api-docs/`：`SKILL.md` 全部改寫；刪除 `src/`、兩支 PHP 入口與多數 scripts；保留 `bin/render-markdown.php`；新增 `references/` 範本。
- `tests/`：刪除 3 支 `laravel_api_docs_*` PHP 測試。
- Laravel 專案端：既有 `docs/api-docs/` 下的 `openapi.yaml`、`history/`、`candidates/`、`conflicts/`、`reviews/`、`versions/` 不再被讀寫，保留原狀由使用者自行處理。`.env.agents` 沿用 `APIDOG_ACCESS_TOKEN`、`APIDOG_PROJECT_ID`。
- 依賴：`jq`、`yq`、`curl`、`php`（只用於 `render-markdown.php` 與 `artisan route:list`）。
- 本 repo 為公開 repo：公司專屬資訊（header 名稱、錯誤碼、Jira 設定）一律不進 repo。
