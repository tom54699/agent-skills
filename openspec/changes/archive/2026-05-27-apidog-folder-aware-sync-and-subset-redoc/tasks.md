## 1. Subset OpenAPI Generation

- [x] 1.1 新增 confirmed-candidate subset OpenAPI 產生工具或共用函式，從完整 `openapi.yaml` 抽出 confirmed `new` / `updated` endpoints。
- [x] 1.2 subset 產物必須保留 `openapi`、`info`、`servers`、`components`、`security`、`tags` 等共用節點。
- [x] 1.3 subset 產生時必須排除 `deleted` candidates，且 candidate path 與 local spec 無匹配時要明確失敗，不產生空 paths payload。

## 2. Folder Mapping

- [x] 2.1 擴充 `upload-apidog.sh`，在 folder-aware delta upload 前呼叫 `GET https://api.apidog.com/api/v1/projects/{projectId}/api-tree-list`。
- [x] 2.2 實作 Apidog API tree parser，支援從 `apiDetailFolder.<id>` 與 `apiDetail.api.folderId` 建立 folder mapping。
- [x] 2.3 實作 folderId 決策順序：candidate `folder_id` override、exact method/path mapping、longest path prefix mapping、明確 fallback。
- [x] 2.4 對無法 mapping 的 candidates 輸出清單；只有在明確 fallback 設定或使用者確認後，才允許使用 root folder `0`。

## 3. Folder-Aware Delta Upload

- [x] 3.1 擴充 delta upload，使 confirmed `new` / `updated` candidates 可依 resolved folderId 分組。
- [x] 3.2 每個 folder group 產生獨立 upload payload，且 `.paths` 僅包含該 folder group 的 candidates。
- [x] 3.3 每個 import request 必須設定該 batch 的 `options.targetEndpointFolderId`，並將 `updateFolderOfChangedEndpoint` 設為 `true`。
- [x] 3.4 `--no-delta` 或未提供 `--candidate-file` 時必須維持既有 full upload 行為，不套用 folder grouping。
- [x] 3.5 所有 folder batches upload 並通過 post-upload verification 後，才 append 一筆 success history；任一批失敗不得寫 success history。

## 4. Redoc Scope Flow

- [x] 4.1 更新 `skills/.curated/laravel-api-docs/SKILL.md`，讓 Step 8 詢問 Redoc 輸出範圍：changed-only 或 full API。
- [x] 4.2 更新 Step 9 指引，changed-only Redoc 必須先產生 subset OpenAPI，再呼叫 `gen-html.sh --openapi <subset>`。
- [x] 4.3 changed-only Redoc 預設輸出到 `docs/api-docs/versions/<version-id>/subset-redoc/` 或使用者指定路徑，不覆蓋 `docs/api-docs/redoc/`。

## 5. Documentation

- [x] 5.1 更新 `docs/laravel-api-docs-guided-sync.md`，記錄 Redoc changed-only/full scope 行為與 subset 輸出位置。
- [x] 5.2 更新 `docs/laravel-api-docs-guided-sync.md`，記錄 Apidog API tree endpoint、folder mapping 決策順序與 fallback 行為。
- [x] 5.3 更新相關 skill 目錄慣例，補上 API tree / mapping artifact 或診斷輸出位置。

## 6. Verification

- [x] 6.1 擴充本地 shell fixture 測試，涵蓋 subset OpenAPI 產生、deleted 排除與 path mismatch 失敗。
- [x] 6.2 擴充本地 shell fixture 測試，涵蓋 API tree folder mapping、`folder_id` override、longest-prefix mapping 與 unmapped fallback gate。
- [x] 6.3 擴充本地 shell fixture 測試，涵蓋 folder-aware batch payload 與 `--no-delta` / no candidate bypass。
- [x] 6.4 執行 `openspec status` / `openspec instructions apply` 與相關 shell 測試，確認 change 可進入實作並維持既有行為。
