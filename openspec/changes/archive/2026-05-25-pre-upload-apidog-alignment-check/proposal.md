## Why

上傳前沒有對齊 Apidog 現有狀態，導致 API 上傳後出現在錯誤資料夾，或因 path prefix 策略（`/api/...` vs `/...`）不一致而產生重複或錯位 endpoint。這個問題在初次使用或換專案時特別容易出現，且通常只有在 Apidog 介面看到結果後才發現。

## What Changes

- `upload-apidog.sh` 在 conflict detection 之前，新增 path strategy 自動比對：從已下載的 remote OpenAPI 偵測遠端實際使用的 path 前綴，與本地 `path_strategy` 比對，不一致時阻擋上傳並提示使用者確認。
- Tags 新增（新資料夾）視為正常行為，不警告。
- 新增 `--skip-alignment-check` flag 可跳過此步驟（CI 或已知環境使用）。
- `SKILL.md` Step 7 補充 alignment check 的觸發說明。

## Capabilities

### New Capabilities

- `apidog-path-strategy-alignment`: 上傳前比對本地 `path_strategy` 與遠端 Apidog 的實際 path 前綴，不一致時阻擋並提示。

### Modified Capabilities

- `laravel-api-docs-guided-sync`: Step 7 新增 alignment check 前置步驟。

## Impact

- `skills/.curated/laravel-api-docs/scripts/upload-apidog.sh`：新增 `detect_alignment_mismatch` 邏輯與 `--skip-alignment-check` flag
- `skills/.curated/laravel-api-docs/SKILL.md`：Step 7 說明更新
