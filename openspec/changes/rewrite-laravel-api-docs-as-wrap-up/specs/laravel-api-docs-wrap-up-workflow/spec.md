## ADDED Requirements

### Requirement: Skill SHALL run as a post-development wrap-up workflow
`laravel-api-docs` skill SHALL 以單一的開發收尾流程運作，依序為：確認範圍 → 撰寫 OpenAPI → 使用者確認 → 上傳 Apidog 並驗證 → 產生 Redoc → 起草 Jira 單。skill MUST 維持在 `skills/laravel-api-docs/`，並以 `SKILL.md` 為入口。

#### Scenario: User finishes development and asks for wrap-up
- **WHEN** 使用者表示開發完成，要產 API 文件、上傳 Apidog、產 Redoc 或開 Jira 單
- **THEN** skill MUST 依上述順序進行，每個需要使用者確認的步驟完成確認後才進入下一步

#### Scenario: User only needs part of the workflow
- **WHEN** 使用者明確表示只需要其中幾個步驟（例如只要 Redoc，不上傳）
- **THEN** skill MUST 只執行指定步驟，且不得略過該步驟本身要求的確認

### Requirement: Scope MUST be confirmed before writing any spec
skill MUST 在撰寫任何 OpenAPI 之前確認本次範圍。AI MUST 依 `git diff <base>...HEAD`、未提交變更與 `php artisan route:list --json` 提出受影響的 API 清單，標明 base branch 以及每支 API 是新增或既有，由使用者確認或增刪。本次只處理確認範圍內的 API。

#### Scenario: AI proposes the scope
- **WHEN** 流程開始
- **THEN** AI MUST 列出候選 API 清單（method、path、controller@action、新增或既有）與使用的 base branch
- **AND** 使用者確認前不得撰寫 spec

#### Scenario: API outside the scope
- **WHEN** 某支 API 不在確認後的範圍內
- **THEN** skill MUST NOT 讀取、修改或上傳它的文件

### Requirement: Route facts MUST come from route:list
operation 的 method、path 與是否需要認證 MUST 取自 `php artisan route:list --json` 的 method、uri 與 middleware，並依專案慣例檔的 path 格式轉換；AI MUST NOT 自行推測。

#### Scenario: Route registered with multiple methods
- **WHEN** 一條 route 的 method 欄位含多個值（例如 `GET|POST|HEAD`）
- **THEN** 除 `HEAD`、`OPTIONS` 外的每個 method MUST 各自視為一支 API

### Requirement: Project conventions MUST live in the Laravel project
專案慣例 MUST 存放在 Laravel 專案的 `docs/api-docs/conventions.md`，內容涵蓋 path 格式、共用 request headers、security、錯誤回應範本、命名規則、description 寫法與參考 API。skill repo 只能提供章節範本，MUST NOT 包含任何公司專屬的值（header 名稱、錯誤碼、Jira 設定等）。

#### Scenario: Conventions file exists
- **WHEN** `docs/api-docs/conventions.md` 存在
- **THEN** AI MUST 在撰寫 spec 前讀取，並依其內容撰寫

#### Scenario: Conventions file is missing
- **WHEN** `docs/api-docs/conventions.md` 不存在
- **THEN** AI MUST 請使用者指定一支參考 API，用 `export-remote.sh` 匯出後依範本起草
- **AND** 使用者確認後才能存檔並繼續流程

### Requirement: New APIs MUST be authored from source code
範圍內 Apidog 上不存在的 API，AI MUST 讀取實際程式碼（Controller、FormRequest 或 inline validation、Service、Transformer／Resource、相關 Exception）依慣例檔撰寫 operation。description MUST 只寫一句，詳細說明放到 `business.md`。

#### Scenario: Error responses
- **WHEN** 撰寫錯誤回應
- **THEN** 只能列出該 action 實際可能發生的錯誤（例如有驗證才有 422、需要認證才有 401），並套用慣例檔的錯誤回應範本

#### Scenario: Response data from a transformer
- **WHEN** 成功回應的 data 由 Transformer 或 Resource 產生
- **THEN** AI MUST 讀取該 Transformer／Resource，依其實際回傳的 key 撰寫 schema 與範例

### Requirement: Existing APIs MUST use the remote version as the base
範圍內已存在於 Apidog 的 API，AI MUST 先用 `export-remote.sh`（含 Apidog extensions）匯出存為 `remote-base.json`，以遠端 operation 為底，只修改程式碼有變動的部分，MUST 保留自訂 header 與 `x-apidog-status` 等 extensions。

#### Scenario: Only one field changed
- **WHEN** 程式碼只新增一個 response 欄位
- **THEN** 新 operation MUST 與遠端版本只差該欄位相關內容

### Requirement: User MUST confirm before upload
上傳前 AI MUST 給使用者確認：新 API 提供摘要（method、path、request 欄位、response、錯誤回應，並列出依據的檔案）；既有 API 提供 `remote-base.json` 與新版本正規化後的 diff。使用者確認前 MUST NOT 上傳。

#### Scenario: User requests changes
- **WHEN** 使用者在確認時要求修改
- **THEN** AI MUST 修改後重新提供摘要或 diff，再次確認後才上傳

### Requirement: Each run MUST write to its own output folder
每次執行 MUST 輸出到 Laravel 專案的 `docs/api-docs/<YYYYMMDD>-<topic>/`，包含 `openapi.yaml`、`upload-targets.json`、`business.md`、`index.html`、`api-docs.html`、`jira.md`，有既有 API 時另含 `remote-base.json`。同名資料夾已存在時 MUST 加上 `-2`、`-3` 等後綴。skill MUST NOT 讀寫 `docs/api-docs/openapi.yaml` 主檔、同步歷史、候選清單、衝突清單、review 檔或 `versions/`。

#### Scenario: Previous run outputs exist
- **WHEN** `docs/api-docs/` 下已有過去的輸出或舊版 guided-sync 檔案
- **THEN** skill MUST 保留它們原狀，不讀取也不修改

### Requirement: Redoc output MUST include a business-logic home page
skill MUST 產生 `index.html` 與 `api-docs.html`。`index.html` 由 `business.md` 產生且必定產生；`business.md` MUST 包含「目的」、「需求」、「業務邏輯（哪些資料會出現、什麼時候出現或消失）」、「前端要改什麼」四個章節。AI 不確定的內容 MUST 標 `TODO`，並在產生 HTML 前讓使用者確認。`api-docs.html` 只包含本次範圍的 API。skill 不負責發佈 HTML。

#### Scenario: Business details are unknown
- **WHEN** AI 無法從程式碼與對話判斷某章節內容
- **THEN** 該章節 MUST 標 `TODO` 並在確認時提出，不得自行編造

### Requirement: Jira tickets MUST be drafted and confirmed before creation
AI MUST 依本次開發內容判斷要起草前端單、後端單或兩者，寫入 `jira.md`；不清楚的部分標 `TODO`。使用者確認草稿前 MUST NOT 建立任何 Jira 單。建立時使用當下 session 可用的工具；沒有可用工具時，交由使用者自行建立。skill MUST NOT 規定固定欄位。

#### Scenario: No Jira tool available
- **WHEN** 使用者確認草稿，但 session 沒有可建立 Jira 單的工具
- **THEN** AI MUST 告知使用者，並提供可直接複製的草稿內容
