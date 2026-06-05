## MODIFIED Requirements

### Requirement: API docs output SHALL keep timestamped version snapshots
系統 SHALL 在正式 Redoc HTML 生成時建立 `docs/api-docs/versions/<version-id>/` 版本快照資料夾，保存本次 OpenAPI、Redoc HTML，以及本次使用的 extra markdown 來源快照。

#### Scenario: Formal Redoc generation creates version folder
- **WHEN** `gen-html.sh` 以正式輸出路徑產生 `docs/api-docs/redoc/api-docs.html`
- **THEN** 系統建立 `docs/api-docs/versions/<version-id>/`
- **AND** `<version-id>` 使用本機時間 `YYYYMMDD-HHMMSS` 格式，若已存在則加上遞增後綴避免覆蓋

#### Scenario: Version folder contains OpenAPI and Redoc files
- **WHEN** 正式 Redoc HTML 生成完成
- **THEN** 版本資料夾 SHALL 包含 `openapi.yaml`
- **AND** SHALL 包含 `redoc/index.html`
- **AND** SHALL 包含 `redoc/api-docs.html`

#### Scenario: Version folder preserves extra markdown when used
- **WHEN** 正式 Redoc HTML 生成啟用 extra markdown
- **THEN** 版本資料夾 SHALL 包含 `redoc/extra.md`
- **AND** 該檔案 SHALL 是本次 HTML 首頁渲染時使用的 markdown 內容快照

#### Scenario: Version folder omits extra markdown when not used
- **WHEN** 正式 Redoc HTML 生成未啟用 extra markdown
- **THEN** 版本資料夾 SHALL NOT 建立 `redoc/extra.md`
