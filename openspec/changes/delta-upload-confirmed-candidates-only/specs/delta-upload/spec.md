## ADDED Requirements

### Requirement: Delta upload filters payload to confirmed candidates only
當 `upload-apidog.sh` 接收到 `--candidate-file` 且未指定 `--no-delta` 時，系統 SHALL 從完整 local spec 中過濾出 confirmed candidates（`new` + `updated`）對應的 paths，並以此 delta spec 作為上傳 payload。

#### Scenario: Delta payload only contains confirmed candidate paths
- **WHEN** `--candidate-file` 指定且包含 N 個 `new`/`updated` candidates
- **THEN** 上傳 payload 的 `.paths` 中只包含這 N 個 endpoint 對應的 path key，其餘 paths 不出現在 payload 中

#### Scenario: Shared nodes are preserved in delta payload
- **WHEN** delta 過濾執行後
- **THEN** `info`、`servers`、`components`、`tags` 等共用節點保持完整，不受過濾影響

#### Scenario: No candidate file falls back to full upload
- **WHEN** 呼叫時未提供 `--candidate-file`
- **THEN** 上傳行為維持現有全量模式，不進行 delta 過濾

### Requirement: --no-delta flag forces full upload
系統 SHALL 提供 `--no-delta` flag，啟用時跳過 delta 過濾，直接上傳完整 local spec，向後相容既有呼叫方式。

#### Scenario: --no-delta bypasses delta filtering
- **WHEN** 呼叫時同時提供 `--candidate-file` 與 `--no-delta`
- **THEN** 上傳 payload 為完整 `openapi.yaml`，delta 過濾邏輯不執行

### Requirement: Empty delta payload is treated as no-op
若 confirmed candidates 的 paths 無法在 local spec 中找到對應 key（path strategy mismatch 等情況），delta payload 的 `.paths` 為空，系統 SHALL 視為 no-op 並回報原因，不執行上傳。

#### Scenario: Delta paths empty after filtering
- **WHEN** candidate file 的所有 path 均無法匹配 local spec 的 path key
- **THEN** 系統輸出警告並中止上傳，不送出空 payload 給 Apidog
