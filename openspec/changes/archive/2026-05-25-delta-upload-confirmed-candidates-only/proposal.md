## Why

目前 `upload-apidog.sh` 每次上傳整份 `openapi.yaml`（全量），即使本次只確認了少數幾個 endpoint，也會把所有 paths 一起推送給 Apidog。這會導致未變動的 endpoint 被舊資料意外覆蓋，且無法精確追蹤「這次實際動了哪些 API」。

## What Changes

- `upload-apidog.sh` 新增 delta 模式：提供 `--candidate-file` 時，自動從 full spec 過濾出 confirmed candidates 對應的 paths，只上傳這些 endpoint。
- `openapi.yaml` 維持現有行為（完整 canonical record），不受影響。
- 新增 `--no-delta` flag 可強制回退至全量上傳（向後相容）。
- `SKILL.md` Step 6 → Step 7 的腳本呼叫說明同步更新，說明 delta 行為與 `--no-delta` 用途。

## Capabilities

### New Capabilities

- `delta-upload`: 依 confirmed candidate file 過濾上傳 payload，只送出本次確認的 endpoint，`info`/`servers`/`components` 等共用節點保持不變。

### Modified Capabilities

- `laravel-api-docs-guided-sync`: Step 7 上傳行為改為 delta-first，需更新 SKILL.md 的 `upload-apidog.sh` 呼叫規格說明。

## Impact

- `skills/.curated/laravel-api-docs/scripts/upload-apidog.sh`：新增 `build_delta_spec` 邏輯與 `--no-delta` flag
- `skills/.curated/laravel-api-docs/SKILL.md`：Step 7 說明更新
