## Why

目前 `laravel-api-docs` 的 guided-sync 在長時間執行時幾乎沒有可觀測性。像 `infer-candidates.sh` 這類初始化範圍較大的腳本，使用者只能看到零散 debug，難以判斷目前跑到哪個階段、還剩多少、慢點在哪裡；代理端也只能靠輪詢猜測狀態。

## What Changes

- 為 guided-sync 腳本建立共用進度與耗時輸出格式。
- 在各腳本執行時顯示整體流程 checklist，並為目前步驟顯示階段進度條。
- 為長時間腳本加入分階段 timing log，至少覆蓋 `infer-candidates.sh` 與 `gen-openapi.sh`。
- 保持各腳本 `stdout` 的 JSON 結果格式可用，進度與 timing 僅輸出到 `stderr`。

## Capabilities

### New Capabilities
- `laravel-api-docs-progress-observability`: guided-sync 腳本必須輸出一致的進度與耗時事件，供使用者與 orchestration 觀察執行狀態。

### Modified Capabilities
- `laravel-api-docs-guided-sync`: guided-sync 執行過程必須對外呈現整體步驟 checklist 與目前步驟進度，而不是只在完成後回報結果。

## Impact

- 影響檔案：
  - `skills/laravel-api-docs/SKILL.md`
  - `skills/laravel-api-docs/scripts/preflight.sh`
  - `skills/laravel-api-docs/scripts/infer-candidates.sh`
  - `skills/laravel-api-docs/scripts/confirm-candidates.sh`
  - `skills/laravel-api-docs/scripts/gen-openapi.sh`
  - `skills/laravel-api-docs/scripts/upload-apidog.sh`
  - `skills/laravel-api-docs/scripts/gen-html.sh`
  - `skills/laravel-api-docs/scripts/progress-lib.sh`（新增）
- 影響行為：
  - guided-sync 執行時會多出 `stderr` 進度與 timing 輸出
  - 長時間腳本完成後可直接看出瓶頸階段
