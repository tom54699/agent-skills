# laravel-api-docs-output-versioning Specification

## Purpose
Define how Laravel API Docs preserves timestamped OpenAPI and Redoc HTML output snapshots while keeping the latest Redoc entry stable.

## Requirements
### Requirement: API docs output SHALL keep timestamped version snapshots
系統 SHALL 在正式 Redoc HTML 生成時建立 `docs/api-docs/versions/<version-id>/` 版本快照資料夾，保存本次 OpenAPI 與 Redoc HTML 輸出。

#### Scenario: Formal Redoc generation creates version folder
- **WHEN** `gen-html.sh` 以正式輸出路徑產生 `docs/api-docs/redoc/api-docs.html`
- **THEN** 系統建立 `docs/api-docs/versions/<version-id>/`
- **AND** `<version-id>` 使用本機時間 `YYYYMMDD-HHMMSS` 格式，若已存在則加上遞增後綴避免覆蓋

#### Scenario: Version folder contains OpenAPI and Redoc files
- **WHEN** 正式 Redoc HTML 生成完成
- **THEN** 版本資料夾 SHALL 包含 `openapi.yaml`
- **AND** SHALL 包含 `redoc/index.html`
- **AND** SHALL 包含 `redoc/api-docs.html`

### Requirement: Latest Redoc entry SHALL remain stable
系統 SHALL 繼續更新 `docs/api-docs/redoc/index.html` 與 `docs/api-docs/redoc/api-docs.html` 作為最新版固定入口。

#### Scenario: Latest entry remains updated
- **WHEN** 正式 Redoc HTML 生成完成
- **THEN** `docs/api-docs/redoc/index.html` 代表最新版首頁
- **AND** `docs/api-docs/redoc/api-docs.html` 代表最新版 API Reference
- **AND** 既有固定入口路徑不因版本化輸出而失效

### Requirement: Non-formal Redoc output SHALL not create official versions
系統 SHALL 只對正式 Redoc 輸出建立 `docs/api-docs/versions/` 備份；自訂 `--output` 路徑不應污染正式版本資料夾。

#### Scenario: Custom output skips official version folder
- **WHEN** `gen-html.sh` 使用非預設 `--output` 路徑產生 HTML
- **THEN** 系統 SHALL 產生指定 HTML 檔案
- **AND** SHALL NOT 建立新的 `docs/api-docs/versions/<version-id>/` 資料夾
