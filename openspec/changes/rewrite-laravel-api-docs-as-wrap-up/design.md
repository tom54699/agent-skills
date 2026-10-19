## Context

現行 `laravel-api-docs` 以 guided-sync 為主：PHP analyzer 依 commit diff 推測候選 API，PHP generator 以 regex 解析 Controller／FormRequest／Service 產出 `docs/api-docs/openapi.yaml`，再經衝突偵測、review loop、同步歷史後上傳 Apidog。實際使用上：

- 最近四次收尾都繞過 guided-sync，改用「AI 讀程式碼手寫 spec → 帶 folder_id 上傳 → changed-only Redoc」。
- 產生器的錯誤是結構性的：追不到 service 呼叫鏈、Transformer 回傳結構、exception handler 定義的專案自訂業務錯誤碼。
- 有 API 只存在 Apidog（自訂 header、`x-apidog-status` 在 Apidog 上維護），主檔已不是唯一來源。

使用者決定：skill 只服務自己的開發收尾流程，不考慮其他使用者；名稱與位置維持 `skills/laravel-api-docs`；repo 為公開 repo，公司專屬資訊不得進 repo。

## Goals / Non-Goals

**Goals:**
- 開發完成後，以一次對話完成：確認範圍 → 撰寫 OpenAPI → 確認 → 上傳 Apidog 並驗證 → 產生 Redoc（含業務邏輯首頁）→ 起草並（確認後）建立 Jira 單。
- 需要理解程式語意的工作交給 AI；與外部系統互動、需要確定性的工作交給腳本。
- 每次輸出自成一個資料夾，不維護跨次狀態。

**Non-Goals:**
- 不再支援整個專案批次產生文件、候選推測、同步歷史、衝突偵測、path strategy 自動偵測。
- 不處理本次範圍外的 API，也不清理 Laravel 專案既有的舊輸出檔。
- 不內建 Jira 整合腳本，不固定 Jira 欄位。
- 不提供給其他人使用的通用化設定。

## Decisions

### D1：移除 PHP 產生器，由 AI 撰寫 OpenAPI

- 選擇：AI 讀 Controller、FormRequest、Service、Transformer／Resource 等實際程式碼，依專案慣例檔撰寫 operation。method、path、middleware 一律取自 `php artisan route:list --json`，不讓 AI 推測。
- 替代方案：
  - 修補產生器（`\R/u`、service 範圍、錯誤碼設定、Transformer 解析）：每項都可修，但 regex 解析 PHP 的上限仍在，且實際已不再使用。
  - 產生器出草稿、AI 修正：仍要維護約 6000 行 PHP，草稿品質不足以節省時間。
- 理由：收尾範圍通常 1～5 支 API，AI 讀檔成本低；端到端比「產草稿 → 抓錯 → 手修」快。

### D2：每次執行一個獨立輸出資料夾，不維護主檔

```
docs/api-docs/<YYYYMMDD>-<topic>/
├── openapi.yaml          # 本次範圍的 spec（AI 撰寫，唯一上傳來源）
├── remote-base.json      # 範圍內既有 API 的遠端匯出（有既有 API 時才有）
├── upload-targets.json   # [{ "method": "post", "path": "/...", "folder_id": 123 }]
├── business.md           # index.html 的來源
├── index.html
├── api-docs.html
└── jira.md               # Jira 草稿
```

- `<topic>` 由 AI 依本次開發內容提出 kebab-case 名稱；同名資料夾已存在時加 `-2`、`-3`。
- 替代方案：保留 `docs/api-docs/openapi.yaml` 主檔並持續合併 → 會與 Apidog 脫節，且使用者明確表示不需要管過去的 API。

### D3：範圍內既有 API 以 Apidog 遠端為底

- 範圍確認後，AI 用 `export-remote.sh` 匯出範圍內 API（`includeApidogExtensionProperties: true`），存為 `remote-base.json`。
- 已存在的 API：以遠端 operation 為底，只修改程式碼有變動的部分，保留自訂 header、`x-apidog-status` 等 extensions。
- 不存在的 API：依慣例檔從頭撰寫。
- `export-remote.sh` 以 `scope: ALL` 匯出後用 jq 篩出指定 method+path，輸出只保留被引用到的 `components`（遞迴收集 `$ref`）。替代方案 `SELECTED_ENDPOINTS` 需要先查 endpoint ID，耦合 Apidog 內部 ID，暫不採用。

### D4：專案慣例放在 Laravel 專案的 `docs/api-docs/conventions.md`

- 內容章節（skill 提供 `references/conventions-template.md` 範本，只有章節與說明，不含公司值）：
  - Path 格式（是否含 `/api` 前綴，取代舊的 path strategy）
  - 共用 request headers（例如語系、Accept、平台來源）與 security
  - 錯誤回應範本（HTTP status → 業務 code、message、範例）
  - 命名規則（例如 key 用 snake_case）
  - description 寫法（只寫一句，詳細說明放首頁）
  - 參考 API：一支寫得好的既有 API（method + path）作為格式範例
- 首次使用找不到此檔時：AI 請使用者指定一支參考 API，用 `export-remote.sh` 匯出後起草，使用者確認後存檔。
- 用 markdown 而非 YAML：只有 AI 讀，腳本不解析。

### D5：範圍確認由 AI 提出、使用者確認

- AI 依 `git diff <base>...HEAD`、未提交變更與 `route:list` 對照出受影響的 route，提出清單（含 base branch、每支 API 是新增或既有）。使用者可增刪。
- 同時蒐集業務背景：需求來源、對話內容、commit 訊息、相關文件，作為 `business.md` 與 Jira 草稿的材料。

### D6：上傳前確認 + 腳本層結構檢查

- AI 層：新 API 給摘要（method、path、request 欄位、response、錯誤碼，並列出依據的檔案）；既有 API 給 `remote-base.json` 與新版本的 diff（`jq -S` 正規化後比對）。使用者確認後才上傳。
- 腳本層：`upload-apidog.sh` 檢查 spec 可解析、每個 target 都存在於 spec、每個 target 都有整數 `folder_id`，否則不上傳。

### D7：上傳一律指定 folder_id，並移除 `x-apidog-folder`

- `upload-targets.json` 每筆都必須有 `folder_id`（根目錄為 `0`）。AI 用 `list-folders.sh` 決定：既有 API 沿用目前所在資料夾；新 API 依同模組既有 API 的位置提出，使用者確認。
- 上傳時依 `folder_id` 分批，每批只含該批 operation 與被引用的 `components`，並移除每個 operation 的 `x-apidog-folder`，避免 Apidog 在目標資料夾下再建一層。
- import 選項沿用現行：`endpointOverwriteBehavior: OVERWRITE_EXISTING`、`schemaOverwriteBehavior: OVERWRITE_EXISTING`、`updateFolderOfChangedEndpoint: true`、`prependBasePath: false`。
- 替代方案：沿用舊的 prefix → folder 自動對應 → 邏輯複雜且曾出錯；明確指定更簡單可預期。

### D8：上傳後驗證路徑與資料夾

- 上傳完成後重新抓 `api-tree-list`，逐一確認每個 target 的 method+path 存在，且所在 folder_id 等於指定值。
- 任何一筆不符即列出差異並以非 0 結束；不做自動修正。

### D9：Redoc 與業務邏輯首頁

- `gen-html.sh --openapi FILE --business-md FILE --output-dir DIR`，輸出 `index.html` 與 `api-docs.html`。`index.html` 必定產生，`business.md` 為必要輸入。
- `business.md` 依 `references/business-template.md`，固定章節：目的、需求、業務邏輯（哪些資料會出現、什麼時候出現或消失）、前端要改什麼。不確定處標 `TODO`，由使用者確認。
- 沿用 `bin/render-markdown.php` 與 Redoc v2.1.3；移除 `versions/` 備份與 progress 輸出。
- 放置位置由使用者自行處理，skill 不負責發佈。

### D10：Jira 草稿與建立前確認

- AI 依本次開發內容判斷要起草前端單、後端單或兩者，寫入 `jira.md`。內容取材自 `business.md` 與 API 清單；不清楚的部分標 `TODO`，不硬寫。
- 使用者確認草稿後，AI 才用當下 session 可用的工具建立；沒有可用工具時，交由使用者複製貼上。skill 不規定欄位。

### D11：腳本精簡與共用

- 保留：`upload-apidog.sh`（改寫）、`gen-html.sh`（精簡）、`bin/render-markdown.php`。
- 新增：`export-remote.sh`、`list-folders.sh`、`apidog-lib.sh`（載入 `.env.agents`、Apidog curl 包裝、YAML→JSON、`components` 修剪）。
- 刪除：`src/`、`bin/infer-candidates.php`、`bin/gen-openapi.php`、`append-sync-history.sh`、`confirm-candidates.sh`、`confirm-openapi-review.sh`、`gen-openapi.sh`、`gen-subset-openapi.sh`、`infer-candidates.sh`、`preflight.sh`、`progress-lib.sh`、`test-upload-changes.sh`。
- 腳本維持 bash 3.2 相容（macOS 預設）。

### D12：舊 spec 處理

- 32 個舊 capability 在實作階段直接刪除 `openspec/specs/<name>/`，change 內只放 2 個新 capability 的 ADDED spec。
- 替代方案：以 REMOVED delta 移除所有 requirement → 已在副本實測，archive 會因「Spec must have at least one requirement」中止，不可行。
- 刪除的 spec 由 git 歷史與 Migration Plan 的 tag 保留。

## Risks / Trade-offs

- [AI 寫出程式碼裡沒有的欄位] → D6 摘要必須列出依據檔案；上傳前使用者確認。
- [每次格式不一致] → conventions.md + 參考 API；既有 API 以遠端為底只改差異。
- [`scope: ALL` 匯出在大型專案較慢] → 可接受；之後真的慢再改 `SELECTED_ENDPOINTS`。
- [`components` 修剪漏掉間接引用] → 遞迴收集 `$ref` 直到不再新增；上傳後驗證能發現 API 缺失但無法發現 schema 缺失，摘要／diff 階段需人工確認。
- [失去整個專案批次產文件的能力] → 已接受；改寫前版本以 git tag 保留，需要時可取回。
- [公開 repo 的其他安裝者遇到破壞性變更] → 使用者明確表示不考慮其他人。

## Migration Plan

1. 改寫前在目前 commit 建立 git tag（例如 `laravel-api-docs-guided-sync-final`），是否 push 由使用者決定。
2. 依 tasks 刪除、改寫、新增檔案，更新 repo 文件與索引。
3. Laravel 專案端不需遷移：舊的 `docs/api-docs/` 檔案保留原狀，新流程不讀寫它們；首次執行時建立 `conventions.md`。
4. Rollback：從 tag 取回 `skills/laravel-api-docs/` 舊版。

## Open Questions

- 無阻擋性問題。Jira 建立方式於執行時依當下可用工具決定。
