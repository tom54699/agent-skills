---
name: laravel-api-docs
description: Laravel 開發完成後的收尾流程：確認這次動到的 API → AI 讀程式碼撰寫 OpenAPI（既有 API 以 Apidog 遠端版本為底）→ 使用者確認 → 依資料夾上傳 Apidog 並驗證 → 產生 Redoc（業務邏輯首頁 + API 規格頁）→ 起草並在確認後建立 Jira 單。當使用者說「開發完了」、「收尾」、「產 API 文件」、「上傳 Apidog」、「產 Redoc」、「開 Jira 單」時觸發。僅用於 Laravel 專案。
metadata:
  version: "2.0.0"
---

# Laravel 開發收尾

開發完成後，用一次對話把 API 文件、Apidog、Redoc 與 Jira 單處理完。

## 原則

1. 只處理本次確認範圍內的 API；過去的 API 與舊輸出都不用管。
2. 需要理解程式語意的工作由 AI 做；和 Apidog 互動、需要確定性的工作用 `scripts/` 的腳本。
3. method、path、是否需要認證一律取自 `php artisan route:list --json`，不推測。
4. 標示 **使用者確認** 的地方要等使用者回覆才往下走；上傳 Apidog 與建立 Jira 單前一定要確認。
5. 公司專屬的值（header、錯誤碼、Jira 設定）只放在 Laravel 專案裡，不寫回 skill repo。
6. 使用者只要其中幾步時，只做那幾步，但該步驟的確認不能省。

## 環境

- 在 Laravel 專案根目錄執行。
- `.env.agents`：`APIDOG_ACCESS_TOKEN`、`APIDOG_PROJECT_ID`。
- 工具：`jq`、`yq`、`curl`、`php`。
- `docs/api-docs/conventions.md`：專案慣例；不存在時依 Step 0 建立。

下文的 `<skill>` 指本 skill 目錄，`<dir>` 指本次輸出資料夾。

## 輸出資料夾

每次執行建立一個新資料夾：

```text
docs/api-docs/<YYYYMMDD>-<topic>/
├── openapi.yaml          # 本次範圍的 spec，唯一上傳來源
├── remote-base.json      # 範圍內既有 API 的遠端匯出（有既有 API 才有）
├── upload-targets.json   # [{"method": "post", "path": "/...", "folder_id": 123}]
├── business.md           # 首頁內容
├── index.html
├── api-docs.html
└── jira.md               # Jira 草稿
```

- `<topic>` 由 AI 依本次開發內容提出 kebab-case 名稱；同名資料夾已存在時加 `-2`、`-3`。
- 不讀寫 `docs/api-docs/` 底下的其他檔案（包含舊版 guided-sync 留下的 `openapi.yaml`、`history/`、`candidates/`、`versions/` 等），保留原狀。

## 流程

### Step 0：讀取專案慣例

- 讀 `docs/api-docs/conventions.md`，後續撰寫都依它。
- 不存在時：請使用者指定一支寫得好的既有 API，用 `export-remote.sh` 匯出後，依 `references/conventions-template.md` 起草。**使用者確認**後存檔。

### Step 1：確認範圍

1. 判斷 base branch（不確定就問），收集變更：`git diff <base>...HEAD --name-only` 與 `git status --short`。
2. 用 `php artisan route:list --json` 對照受影響的 controller／action，列出 API。一條 route 有多個 method 時，除 `HEAD`、`OPTIONS` 外每個 method 各算一支。
3. 用 `bash <skill>/scripts/list-folders.sh --apis` 判斷每支 API 在 Apidog 上是否已存在。path 要依 `conventions.md` 的 path 格式轉換後再比對。
4. 提出清單：method、path、controller@action、新增或既有，以及使用的 base branch。
5. 同時蒐集業務背景：需求來源、對話內容、commit 訊息、相關文件，作為 `business.md` 與 Jira 草稿的材料。
6. **使用者確認**清單（可增刪）後才往下。範圍外的 API 不讀、不改、不上傳。

### Step 2：撰寫 OpenAPI

建立輸出資料夾後，依 API 是新增或既有分別處理，結果寫入 `<dir>/openapi.yaml`（只含本次範圍的 API）。

**既有 API**：先匯出遠端版本當底。

```bash
bash <skill>/scripts/export-remote.sh \
  --endpoint "POST /path/a" --endpoint "GET /path/b" \
  --output <dir>/remote-base.json
```

- 以遠端 operation 為底，只修改程式碼有變動的部分。
- 保留自訂 header、`x-apidog-status` 等 `x-apidog-*` extensions。
- 結果的 `missing` 代表 Apidog 上沒有這支 API，改當新 API 處理。

**新 API**：讀實際程式碼（Controller、FormRequest 或 inline validation、Service、Transformer／Resource、相關 Exception），依 `conventions.md` 撰寫。

撰寫規則：

- 錯誤回應只列該 action 實際會發生的：有驗證才有 422、需要認證才有 401，並套用慣例的錯誤回應範本。
- 只看該 action 與它實際呼叫到的 service method；同一個 Controller／Service 其他 method 的錯誤不算進來。
- response data 由 Transformer／Resource 產生時，讀它實際回傳的 key 撰寫 schema 與範例。
- description 只寫一句；詳細說明寫進 `business.md`。

### Step 3：上傳前確認

1. 給使用者看內容：
   - 新 API：摘要（method、path、request 欄位、response、錯誤回應），並列出依據的檔案。
   - 既有 API：`remote-base.json` 與新版本的 diff，例如：
     ```bash
     diff <(jq -S '.paths["/path/a"].post' <dir>/remote-base.json) \
          <(yq -o=json '.paths["/path/a"].post' <dir>/openapi.yaml | jq -S .)
     ```
2. 決定資料夾，寫入 `<dir>/upload-targets.json`（根目錄 `folder_id` 為 `0`）：
   - 既有 API：沿用 `list-folders.sh --apis` 顯示的目前資料夾。
   - 新 API：依同模組既有 API 的位置或 `conventions.md` 的資料夾習慣提出；用 `list-folders.sh` 查 folder ID。
3. **使用者確認**內容與資料夾後才上傳；要修改就改完重新確認。

### Step 4：上傳 Apidog

```bash
bash <skill>/scripts/upload-apidog.sh \
  --openapi <dir>/openapi.yaml \
  --targets <dir>/upload-targets.json
```

- 先檢查 spec 可解析、targets 欄位完整、每個 target 都在 spec 裡；失敗時不送任何請求。
- 依 `folder_id` 分批上傳，移除 `x-apidog-folder`（避免在目標資料夾下多建一層），只帶被引用的 components。
- 上傳後重抓 API tree，驗證每支 API 存在且位於指定資料夾。失敗時列出差異交給使用者決定，不自行重試或搬移。

### Step 5：產生 Redoc

1. 依 `references/business-template.md` 撰寫 `<dir>/business.md`：目的、需求、業務邏輯（哪些資料會出現、什麼時候出現或消失）、前端要改什麼。判斷不出來的寫 `TODO：<缺什麼>`，不自行編造。
2. **使用者確認** `business.md`，特別是 `TODO` 的部分。
3. 產生 HTML：
   ```bash
   bash <skill>/scripts/gen-html.sh \
     --openapi <dir>/openapi.yaml \
     --business-md <dir>/business.md \
     --output-dir <dir>
   ```
4. 告知 `index.html` 與 `api-docs.html` 的位置；放到哪裡由使用者處理。

### Step 6：Jira 單

1. 依本次開發內容判斷要開前端單、後端單或兩者，寫入 `<dir>/jira.md`。
   - 內容取材自 `business.md` 與 API 清單；不清楚的地方標 `TODO`，不硬寫。
   - 不固定欄位；使用者有指定專案、類型或欄位就照做。
2. **使用者確認**草稿。
3. 用當下 session 可用的工具建立（例如 Jira／Atlassian 的 MCP 工具）。沒有可用工具時，告知使用者並提供可直接複製的內容。

## 腳本

| 腳本 | 用途 |
|---|---|
| `scripts/export-remote.sh` | 帶 Apidog extensions 匯出指定 API 與它引用的 components |
| `scripts/list-folders.sh` | 列出資料夾路徑與 ID；`--apis` 列出每支 API 所在資料夾；`--json` 輸出 JSON |
| `scripts/upload-apidog.sh` | 檢查 → 依資料夾分批上傳 → 驗證路徑與資料夾 |
| `scripts/gen-html.sh` | 由 spec 與 `business.md` 產生 `index.html`、`api-docs.html` |
| `scripts/apidog-lib.sh` | 共用函式，由其他腳本 source |

結構化結果走 stdout，訊息與錯誤走 stderr。

## 錯誤處理

- 缺少 Apidog 設定：請使用者在 `.env.agents` 補上 `APIDOG_ACCESS_TOKEN`、`APIDOG_PROJECT_ID`。
- 讀不到 API tree 或匯出失敗：多半是 token 或專案權限不足，把錯誤訊息給使用者確認。
- 使用者認為某支 API 應該存在，`export-remote.sh` 卻回報 missing：先確認 path 格式是否和 Apidog 上一致。
- 上傳後驗證失敗：列出差異，請使用者決定要到 Apidog 手動調整，還是修正 `folder_id` 後重傳。
