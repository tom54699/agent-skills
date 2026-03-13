## Why

目前 Step 7 會把 confirmed `updated` 但遠端 Apidog export 找不到對應 operation 的 endpoint 一律標成 `missing_remote_endpoint` conflict。這在初始化模式會過度保守，導致本地已補強完成的 updated OpenAPI 無法同步到 Apidog。

## What Changes

- 調整 Apidog updated conflict 判斷，區分「真正欄位衝突」與「遠端不存在 operation」。
- 在初始化模式下，對 confirmed `updated` 且遠端不存在的 endpoint，允許視為可由本地建立，而不是一律阻擋。
- 調整 `keep_remote` 策略，只保留真正存在 remote operation 且欄位不一致的項目；對 remote missing 項目不得把本地 operation 移除。
- 保留 conflict file 與 history 契約，但讓 `missing_remote_endpoint` 不再造成 updated 全數被吞掉。

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `laravel-api-docs-apidog-conflict-sync`: refined handling for confirmed `updated` endpoints that are absent from remote Apidog OpenAPI during initialization-oriented syncs.

## Impact

- 影響 `skills/laravel-api-docs/scripts/upload-apidog.sh`
- 影響 Step 7 conflict file 內容與 `keep_remote` 的實際上傳結果
- 影響 `skills/laravel-api-docs/SKILL.md` 對 updated conflict 行為的描述
