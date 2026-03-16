## Why

部分 Laravel 專案的 `php artisan route:list --json` 會在真正 JSON 之前輸出 PHP startup warning，例如遺失 extension 的訊息。當這些警告被寫進 stdout 時，現有腳本直接把整段資料丟給 `jq`，會造成候選推測與 OpenAPI 產生在一開始就失敗。

## What Changes

- 讓 `infer-candidates.sh` 與 `scan-routes.sh` 在解析 `route:list --json` 前先移除前導非 JSON 行。
- 保持既有 route parsing 邏輯不變，只增加對髒 stdout 的容錯。

## Impact

- 影響檔案：
  - `skills/laravel-api-docs/scripts/infer-candidates.sh`
  - `skills/laravel-api-docs/scripts/scan-routes.sh`
