## ADDED Requirements

### Requirement: Apidog scripts MUST load credentials from .env.agents
`export-remote.sh`、`list-folders.sh`、`upload-apidog.sh` MUST 從 Laravel 專案根目錄的 `.env.agents` 讀取 `APIDOG_ACCESS_TOKEN` 與 `APIDOG_PROJECT_ID`。缺少任一值時 MUST 以明確訊息失敗並以非 0 結束，不得送出任何請求。

#### Scenario: Missing token
- **WHEN** `.env.agents` 不存在或缺少 `APIDOG_ACCESS_TOKEN`
- **THEN** 腳本 MUST 指出缺少的設定並以非 0 結束

### Requirement: export-remote.sh MUST export selected APIs with Apidog extensions
`export-remote.sh` MUST 接受一或多組 method+path 與輸出檔路徑，以 `includeApidogExtensionProperties: true` 匯出 Apidog 規格，只保留指定的 operation 與它們遞迴引用到的 `components`。

#### Scenario: Export an existing API
- **WHEN** 指定的 method+path 存在於 Apidog
- **THEN** 輸出 MUST 包含該 operation 的完整內容，含自訂 header 與 `x-apidog-*` extensions
- **AND** 輸出 MUST 包含它直接或間接 `$ref` 到的所有 `components`，不包含未被引用的 `components`

#### Scenario: Requested API not found
- **WHEN** 有指定的 method+path 不存在於 Apidog
- **THEN** 腳本 MUST 列出找不到的 method+path，並在結果中標示，讓 AI 判斷該 API 為新增

### Requirement: list-folders.sh MUST list folder paths and IDs
`list-folders.sh` MUST 從 Apidog API tree 列出每個資料夾的完整路徑與 folder ID（例如 `Driver/Order → 123`），並可選擇列出每支 API 目前所在的資料夾。

#### Scenario: Look up an API's current folder
- **WHEN** AI 需要決定既有 API 的 `folder_id`
- **THEN** `list-folders.sh` MUST 能輸出該 API（method+path）目前所在的資料夾路徑與 ID

### Requirement: upload-apidog.sh MUST validate inputs before uploading
`upload-apidog.sh` MUST 接受 spec 檔與 `upload-targets.json`。上傳前 MUST 檢查：spec 可解析；每個 target 都有 method、path 與整數 `folder_id`；每個 target 都存在於 spec。任一檢查失敗 MUST 列出問題並以非 0 結束，不得送出任何上傳請求。

#### Scenario: Target missing from spec
- **WHEN** `upload-targets.json` 有一筆 method+path 不在 spec 中
- **THEN** 腳本 MUST 列出該筆並以非 0 結束，不上傳任何內容

### Requirement: upload-apidog.sh MUST upload in folder batches without x-apidog-folder
`upload-apidog.sh` MUST 依 `folder_id` 分批上傳，每批只包含該批 operation 與被引用的 `components`，以該 `folder_id` 作為 `targetEndpointFolderId`。每個 operation 的 `x-apidog-folder` MUST 在上傳前移除。

#### Scenario: Spec exported from Apidog still carries x-apidog-folder
- **WHEN** 上傳的 operation 帶有 `x-apidog-folder`
- **THEN** 上傳內容 MUST 不含 `x-apidog-folder`，API 只能落在指定的 `folder_id`，不得多建一層資料夾

### Requirement: upload-apidog.sh MUST verify path and folder after upload
上傳完成後，`upload-apidog.sh` MUST 重新讀取 Apidog API tree，確認每個 target 的 method+path 存在且位於指定的 `folder_id`。任一筆不符 MUST 列出差異並以非 0 結束。

#### Scenario: API lands in the wrong folder
- **WHEN** 上傳後某支 API 所在資料夾與指定的 `folder_id` 不同
- **THEN** 腳本 MUST 列出該 API、預期資料夾與實際資料夾，並以非 0 結束

#### Scenario: All targets verified
- **WHEN** 所有 target 都存在且位於指定資料夾
- **THEN** 腳本 MUST 回報成功，並輸出新增、更新的數量
