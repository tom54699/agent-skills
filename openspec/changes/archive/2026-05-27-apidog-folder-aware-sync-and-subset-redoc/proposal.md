## Why

目前 guided-sync 的尾端流程有兩個實務落差：Redoc HTML 只能從完整 `openapi.yaml` 產生，無法只輸出本次同步的 API；Apidog 上傳固定使用 root folder，導致新 API 被放到根層，無法延續既有 Apidog 專案資料夾結構。

這次變更要讓同步結果更貼近日常對接與 Apidog 協作情境：本次變更可以產出精簡 Redoc，Apidog 上傳也能依既有 API tree 分批送到正確資料夾。

## What Changes

- Step 8 詢問是否產生 Redoc HTML 時，增加輸出範圍選項：
  - 只產本次 confirmed candidates 對應的 API
  - 產完整 API 文件
- Step 9 支援從 confirmed candidates 產生 subset OpenAPI，並以 `gen-html.sh --openapi <subset>` 產生本次變更 Redoc。
- subset Redoc 預設不覆蓋 `docs/api-docs/redoc/` 正式完整文件入口；正式完整 Redoc 仍維持最新版固定入口與版本快照規則。
- 新增 Apidog API tree discovery：呼叫 `GET https://api.apidog.com/api/v1/projects/{projectId}/api-tree-list`，建立 API path/method 與 path prefix 到 `folderId` 的 mapping。
- `upload-apidog.sh` 依 confirmed candidates 的 mapping 分批產生 upload payload，對每批帶入對應 `targetEndpointFolderId`。
- confirm 階段允許使用者為 candidate 指定或覆寫 `folder_id`，作為 mapping 不明確時的人工補正。
- 若無法取得 API tree 或找不到對應 mapping，流程應明確回報並採可預期 fallback，而不是默默全部丟到 root。

## Capabilities

### New Capabilities

- `apidog-folder-aware-upload`: 定義如何取得 Apidog 專案 API tree、建立 folder mapping，並讓 upload 依 folder 分批送出。

### Modified Capabilities

- `laravel-api-docs-guided-sync`: Step 8/9 的 Redoc 產生範圍選擇與 guided-sync 上傳流程需要新增 folder-aware 行為。
- `delta-upload`: delta payload 需支援依 folder 分批產生與上傳，仍只包含 confirmed candidates。

## Impact

- 影響 skill 規格與互動流程：`skills/.curated/laravel-api-docs/SKILL.md`
- 影響 Apidog 上傳腳本：`skills/.curated/laravel-api-docs/scripts/upload-apidog.sh`
- 可能新增或擴充 subset OpenAPI 產生工具，供 Redoc 與分批 upload 共用。
- 影響文件：`docs/laravel-api-docs-guided-sync.md`
- 依賴 Apidog 內部 API：`/api/v1/projects/{projectId}/api-tree-list`，需 Bearer token 與 `X-Apidog-Api-Version: 2024-03-28`。
