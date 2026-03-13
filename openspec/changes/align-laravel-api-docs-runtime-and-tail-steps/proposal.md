## Why

`laravel-api-docs` 的核心主路徑已經改成 PHP analyzer / PHP generator，但 Step 1 preflight 仍未檢查 PHP 執行條件，導致流程可能在 Step 4 或 Step 6 才失敗。另外，Step 7 的 Apidog 衝突處理與 Step 9 的 Redoc `extra.md` 尚未與 `SKILL.md` 對齊，造成規格與實作落差。

## What Changes

- 在 preflight 補上 PHP runtime readiness 檢查，至少驗證 `php`、`php -n` 與 `php -n artisan route:list --json` 可用。
- 補齊 Apidog updated conflict detection、conflict file 輸出與預設 `keep_remote` 規則。
- 補齊 Redoc HTML 對 `docs/api-docs/redoc/extra.md` 的可選載入能力。
- 清理已退出主路徑的過渡 shell 腳本與文件，避免 skill 對外仍呈現雙路徑狀態。

## Capabilities

### New Capabilities
- `laravel-api-docs-runtime-readiness`: Preflight must validate PHP runtime readiness for the PHP-based analyzer and generator path.
- `laravel-api-docs-apidog-conflict-sync`: Guided-sync must detect updated conflicts, emit a conflict file, and apply explicit conflict strategies before history append.
- `laravel-api-docs-redoc-extra-content`: Redoc HTML generation must optionally embed or render `docs/api-docs/redoc/extra.md` without mutating OpenAPI.

### Modified Capabilities

## Impact

- Affected scripts:
  - `skills/laravel-api-docs/scripts/preflight.sh`
  - `skills/laravel-api-docs/scripts/upload-apidog.sh`
  - `skills/laravel-api-docs/scripts/gen-html.sh`
- Affected docs:
  - `skills/laravel-api-docs/SKILL.md`
- Affected workflow artifacts:
  - `docs/api-docs/conflicts/<timestamp>.json`
  - `docs/api-docs/redoc/extra.md`
- Cleanup target:
  - transitional shell parsers / route scanner no longer used in runtime main path
