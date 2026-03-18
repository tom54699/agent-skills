## Why

目前 `laravel-api-docs` 會在掃描 Laravel routes 後，直接將 `api/` 前綴從 path 中裁掉，改由 OpenAPI `servers.url` 承接。這其實是一種路徑策略選擇，不是所有專案或 Apidog 專案都採同一種表示方式；若在初始化時沒有先確認，後續生成、比對與同步都可能建立在錯誤的 path 契約上。

## What Changes

- 在初始化流程中加入強制的 API path strategy 選擇步驟。
- 支援至少兩種策略：
  - 保留完整 Laravel path，例如 `/api/admin/...`
  - 將 `/api` 視為 base path，由 `servers.url` 承接，`paths` 使用 `/admin/...`
- 將選定的 path strategy 持久化，讓後續 daily inference、OpenAPI generation 與 merge 一律沿用同一策略。
- 補強文件與 debug/meta，讓使用者能看出目前專案使用的 path strategy。
- 明確與 GET query parameter 生成變更分開管理，但實作上可同批協調驗證。

## Capabilities

### New Capabilities
- `laravel-api-docs-path-strategy`: 定義 Laravel route path 與 OpenAPI `paths`/`servers` 的對應策略，以及後續流程必須一致沿用。

### Modified Capabilities
- `laravel-api-docs-bootstrap-initialization`: 初始化流程必須要求使用者確認 path strategy，並在首次建立專案基準時持久化。

## Impact

- 影響檔案：
  - `skills/.curated/laravel-api-docs/src/InferCandidates/Analyzer.php`
  - `skills/.curated/laravel-api-docs/src/OpenApiGenerator/OpenApiGenerator.php`
  - `skills/.curated/laravel-api-docs/SKILL.md`
  - `docs/laravel-api-docs-guided-sync.md`
- 影響資料契約：
  - history 或其他專案設定需保存 path strategy
  - candidate / debug meta 可能需要暴露目前使用策略
- 影響流程：
  - 首次初始化多一個必選決策
  - 後續 daily run 不再自行假設是否裁掉 `/api`
