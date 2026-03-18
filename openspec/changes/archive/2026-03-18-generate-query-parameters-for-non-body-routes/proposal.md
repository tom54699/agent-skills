## Why

目前 `laravel-api-docs` 的 OpenAPI generator 只有在 body method 時才會解析 FormRequest 與 inline validation，導致 GET 等非 body 請求即使明確定義了查詢參數規則，也不會產出 `parameters`。這會讓 generated OpenAPI 漏掉 query string 契約，影響文件正確性與 Apidog 同步品質。

## What Changes

- 擴充 OpenAPI generator，讓非 body 請求也會解析 FormRequest 與 inline validation。
- 將可映射的 Laravel validation 欄位輸出為 OpenAPI `parameters`，預設以 `in: query` 表示。
- 保留 body method 現有 `requestBody` 生成邏輯，不把 GET/DELETE 等非 body 請求誤生成为 `requestBody`。
- 明確定義 query parameter 的 required、schema、example 與 description 映射規則。
- 補上對應測試與文件，說明 generator 何時產生 `requestBody`、何時產生 `parameters`。

## Capabilities

### New Capabilities
- `laravel-openapi-query-parameter-generation`: 定義非 body 請求的 validation 規則必須被轉譯為 OpenAPI query parameters。

### Modified Capabilities
- `laravel-openapi-request-validation-enrichment`: request validation 生成能力需明確區分 body 與 non-body 請求的輸出目標。

## Impact

- 影響檔案：
  - `skills/.curated/laravel-api-docs/src/OpenApiGenerator/OpenApiGenerator.php`
  - `skills/.curated/laravel-api-docs/src/InferCandidates/FormRequestParser.php`
  - `skills/.curated/laravel-api-docs/src/InferCandidates/ControllerParser.php`
  - `skills/.curated/laravel-api-docs/SKILL.md`
  - `docs/laravel-api-docs-guided-sync.md`
- 影響輸出：
  - `docs/api-docs/openapi.yaml` 的 GET / non-body operations 會新增 `parameters`
  - Apidog 匯入後的查詢參數可見性會提升
- 影響測試：
  - 需新增 GET/FormRequest、GET/inline validation 與 body/non-body 分流測試
