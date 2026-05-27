## Context

`laravel-api-docs` guided-sync 目前已經能從 confirmed candidates 產生 delta upload payload，但尾端仍有兩個限制：

- `gen-html.sh` 預設吃完整 `docs/api-docs/openapi.yaml`，Step 8/9 沒有讓使用者選擇「只產本次變更 API」。
- `upload-apidog.sh` 建立 import request 時固定使用 `targetEndpointFolderId: 0`，新 API 會落在 Apidog root folder。

Apidog 公開 OpenAPI 文件沒有 folder tree endpoint；目前可用的是內部 API：

```text
GET https://api.apidog.com/api/v1/projects/{projectId}/api-tree-list
Authorization: Bearer {token}
X-Apidog-Api-Version: 2024-03-28
```

此 endpoint 必須使用 `/api/v1/` 前綴；`/v1/` 會導回文件頁。

## Goals / Non-Goals

**Goals:**

- guided-sync Step 8/9 讓使用者選擇產生完整 Redoc 或本次 confirmed candidates subset Redoc。
- subset Redoc 由完整 `openapi.yaml` 抽出 confirmed candidates 對應 paths，保留共用節點。
- Apidog upload 在 delta 模式下能依 folderId 分批上傳，避免新 API 全部落在 root。
- 支援從 Apidog API tree 建立 mapping，也允許使用者於 confirm 階段覆寫 candidate 的 `folder_id`。
- post-upload verification 與 sync history 仍維持原本語意：所有必要批次成功驗證後才寫 success history。

**Non-Goals:**

- 不把 Apidog 內部 API 包裝成公開穩定契約；若 endpoint 不可用，流程需降級或要求使用者確認。
- 不改變 `docs/api-docs/openapi.yaml` 作為 Apidog sync 唯一主來源的原則。
- 不嘗試從 export OpenAPI 的 `x-apidog-folder` 或 tags 反推 folder，因為實務上可能為空。
- 不改造 Redoc 版面或建立新的 HTML UI。

## Decisions

### 1. 抽出共用 subset spec 產生邏輯

新增或擴充一個小型工具，輸入完整 OpenAPI 與 candidate file，輸出 subset OpenAPI：

```text
openapi.yaml + confirmed.json + filters -> subset.openapi.json/yaml
```

此工具應支援：

- 依 candidate 的 `method` + `path` 選取 paths。
- 只納入 `new` 與 `updated` endpoint；`deleted` 不進 upload 或 Redoc subset。
- 保留 `openapi`、`info`、`servers`、`components`、`security`、`tags` 等共用節點。
- 找不到 candidate path 時回報明確錯誤或 no-op，不產生空 paths payload。

選擇這個設計，是因為 `gen-html.sh` 已支援 `--openapi FILE`，不需要讓 HTML 腳本理解 candidate schema。upload 也已經有 delta 概念，抽 subset 可以成為共同基礎。

替代方案是直接在 `gen-html.sh` 加 `--candidate-file`，但會讓 HTML 腳本跨入 sync domain，耦合較高。

### 2. Redoc subset 預設不覆蓋正式完整入口

當使用者選擇「只產本次變更 API」時，輸出應使用明確的 subset 輸出路徑，例如：

```text
docs/api-docs/versions/<version-id>/subset-redoc/
```

或使用使用者指定的 `--output` 路徑。預設不得覆蓋：

```text
docs/api-docs/redoc/index.html
docs/api-docs/redoc/api-docs.html
```

原因是 `docs/api-docs/redoc/` 現有語意是「最新版完整文件入口」。如果一次只同步 3 支 API 後覆蓋正式入口，對外分享的文件會突然缺少歷史 API。

### 3. API tree discovery 在 upload 前執行，並可快取為本次 artifact

folder mapping 建議在 Step 7 upload 前執行，而不是 Step 1 preflight 強制執行。理由：

- Step 1 應維持環境檢查，不應因 Apidog 內部 API 暫時不可用而阻擋前面候選推測與 OpenAPI 生成。
- folder mapping 真正只影響 upload。
- 若使用者只想產 Redoc，不需要呼叫 Apidog tree。

實作上可把 tree response 與解析後 mapping 寫到：

```text
docs/api-docs/apidog-tree/<timestamp>.json
docs/api-docs/apidog-tree/<timestamp>.mapping.json
```

若不想新增持久 artifact，也可先使用 `/tmp` 檔案；但正式文件需描述資料來源與除錯方式。

### 4. folderId 決策順序

每個 candidate 的目標 folderId 依序決定：

1. candidate confirmed file 中明確指定的 `folder_id`
2. API tree 中相同 method + path 的既有 `api.folderId`
3. API tree 中最長 path prefix 對應的 folderId
4. 使用者確認的 fallback folderId
5. root folder `0`

第 4、5 步不得靜默發生。流程必須輸出無法 mapping 的 candidate 清單，讓使用者知道哪些 API 會被放到 fallback。

### 5. upload 依 folderId 分批，history 最後一次寫入

delta payload 先根據 confirmed candidates 抽 subset，再依目標 folderId 分組。每個 folderId 產生一個 import-openapi request：

```json
{
  "input": "<subset spec string>",
  "options": {
    "targetEndpointFolderId": 1417834,
    "endpointOverwriteBehavior": "OVERWRITE_EXISTING",
    "updateFolderOfChangedEndpoint": true
  }
}
```

所有批次都完成 post-upload verification 後，才 append 一筆 success history。若任一批次失敗，整次 sync 視為失敗，不寫 success history。

### 6. import-openapi endpoint 暫不跟著改成 `/api/v1/`

已確認 `api-tree-list` 必須使用 `/api/v1/`。但既有 `import-openapi` 目前在腳本內使用 `/v1/projects/{id}/import-openapi`，且這是公開文件列出的 API 類型。此 change 不主動改 import endpoint，除非實作驗證證明它也需要 `/api/v1/`。

## Risks / Trade-offs

- Apidog 內部 API 可能變更或權限不足 → 將 tree discovery 做成可診斷步驟，403/404/302 都輸出明確原因，並允許使用者手動指定 `folder_id`。
- path prefix mapping 可能猜錯 folder → 使用 longest-prefix 只作 fallback；相同 method/path 與 explicit `folder_id` 優先。
- 分批 upload 會增加請求數 → 只針對 confirmed candidates delta 分批，批次數通常等於本次變更涉及的 folder 數。
- 部分批次成功、部分失敗會造成遠端部分更新 → 不寫 success history，回報成功/失敗批次，讓使用者可修正後重跑；post-upload verification 仍是最終判斷。
- subset Redoc 與正式完整 Redoc 會有不同輸出位置 → Step 8 需清楚說明選項，避免使用者誤以為 subset 會更新正式分享入口。

## Migration Plan

1. 先新增 subset spec 產生工具或函式，並讓現有 delta upload 測試通過。
2. 擴充 Step 8/9 文件與 skill 指引，支援 subset Redoc 選項。
3. 新增 Apidog tree discovery 與 mapping 解析，先以 dry-run/diagnostic 輸出驗證。
4. 擴充 upload 分批邏輯與 post-upload verification。
5. 更新 `docs/laravel-api-docs-guided-sync.md`，記錄 `/api/v1/` tree endpoint、mapping 規則與 fallback 行為。

Rollback 時可停用 folder-aware upload，回到既有 root folder 行為；subset Redoc 不影響主 OpenAPI 與 sync history。

## Open Questions

- subset Redoc 的正式預設輸出位置固定為 `docs/api-docs/versions/<version-id>/subset-redoc/`；使用者可用 `--output` 指定其他位置。
- `folder_id` 直接支援寫入 confirmed candidate file；同時 upload 會產生 `docs/api-docs/apidog-tree/<timestamp>.decisions.json` 作為本次 mapping decision artifact。
- 新 endpoint 沒有可推導 prefix 時，不會自動 fallback 到 root `0`；必須由使用者明確確認，或命令明確加上 `--allow-root-folder-fallback`。
