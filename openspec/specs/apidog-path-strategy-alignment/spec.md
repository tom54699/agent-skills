# apidog-path-strategy-alignment Specification

## Purpose
Define how Laravel API Docs validates local and remote Apidog path strategies before upload.

## Requirements
### Requirement: Path strategy is compared against remote Apidog before upload
`upload-apidog.sh` 在取得 remote OpenAPI 後、執行 conflict detection 前，SHALL 比對本地 `path_strategy` 與從遠端 spec 偵測到的 path strategy；兩者不一致時中止上傳並輸出說明。

#### Scenario: Strategies match, upload proceeds
- **WHEN** 本地 `path_strategy` 與遠端偵測結果相同
- **THEN** alignment check 靜默通過，上傳繼續

#### Scenario: Strategies mismatch, upload is blocked
- **WHEN** 本地 `path_strategy` 為 `strip-api-prefix-to-server`，但遠端路徑含 `/api/` 前綴（偵測為 `keep-full-path`）
- **THEN** 系統輸出 alignment warning 說明雙方差異，並中止上傳，提示使用者以 `--skip-alignment-check` 繼續或調整 strategy

#### Scenario: Remote paths are empty, check is skipped
- **WHEN** 遠端 Apidog 尚無任何 endpoint（全新專案）
- **THEN** alignment check 靜默跳過，不阻擋上傳

#### Scenario: Remote strategy cannot be determined, check is skipped
- **WHEN** `detect_path_strategy_from_openapi` 回傳空字串（路徑樣本不足）
- **THEN** alignment check 靜默跳過，不阻擋上傳

### Requirement: --skip-alignment-check bypasses the check
系統 SHALL 提供 `--skip-alignment-check` flag，啟用時跳過 path strategy 比對，適用於 CI 或已知環境。

#### Scenario: Flag suppresses alignment check
- **WHEN** 呼叫時提供 `--skip-alignment-check`
- **THEN** alignment check 邏輯完全跳過，不輸出任何 warning

### Requirement: Tag additions are not treated as errors
遠端新增 tag（對應 Apidog 新資料夾）SHALL 視為正常行為，不產生 warning 或阻擋。

#### Scenario: New tags in local spec silently pass
- **WHEN** 本地 spec 含有遠端不存在的 tag（例如新功能模組）
- **THEN** alignment check 不輸出任何 warning，上傳繼續
