## Why

目前 guided-sync 產生 Redoc HTML 時固定覆蓋 `docs/api-docs/redoc/index.html` 與 `docs/api-docs/redoc/api-docs.html`，而 `docs/api-docs/openapi.yaml` 也只保留最新版本。這讓每次同步後缺少可回溯的文件快照，無法快速比對或復原歷史輸出。

## What Changes

- 每次產生 Redoc HTML 時，同步建立 `docs/api-docs/versions/<timestamp>/` 版本資料夾。
- 將本次 `docs/api-docs/openapi.yaml` 複製為版本快照：`docs/api-docs/versions/<timestamp>/openapi.yaml`。
- 將本次 Redoc HTML 輸出寫入版本資料夾：`docs/api-docs/versions/<timestamp>/redoc/index.html` 與 `api-docs.html`。
- 繼續更新 `docs/api-docs/redoc/` 作為最新版固定入口，避免既有分享路徑失效。
- 更新 guided-sync 流程與文件，讓 Step 9 明確揭露最新版入口與版本備份路徑。

## Capabilities

### New Capabilities
- `laravel-api-docs-output-versioning`: 定義 OpenAPI 與 Redoc HTML 的版本化輸出與備份契約。

### Modified Capabilities
- `laravel-api-docs-guided-sync`: guided-sync 的 HTML 產生階段需建立版本化輸出，並保留最新版固定入口。

## Impact

- 影響 `skills/.curated/laravel-api-docs/scripts/gen-html.sh` 的輸出流程。
- 影響 `skills/.curated/laravel-api-docs/scripts/preflight.sh` 的必要目錄建立。
- 影響 `skills/.curated/laravel-api-docs/SKILL.md` 與 `docs/laravel-api-docs-guided-sync.md` 的流程說明。
- 新增 `docs/api-docs/versions/` 目錄慣例；不改變 Apidog 同步唯一來源仍為 `docs/api-docs/openapi.yaml`。
