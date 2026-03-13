## Why

目前 `gen-openapi` 產出的 `updated` endpoint 文件太薄，只包含基礎 request schema 與預設 responses，缺少更完整的參數規則、錯誤資訊與 examples。即使同步到 Apidog，文件仍不足以支撐前後端協作與測試。

## What Changes

- 擴充 FormRequest 規則解析，讓 request schema 能反映更多驗證規則，而不只 `required` 與少數欄位限制。
- 擴充 `updated` endpoint 的 response 產生邏輯，補強成功與錯誤回應的 schema 與錯誤資訊來源。
- 為 requestBody 與 responses 產生可用的 examples，優先覆蓋 `updated` endpoint。
- 同步更新 `SKILL.md`，明確說明 `updated` endpoint 的文件 enrich 目標。

## Capabilities

### New Capabilities
- `laravel-openapi-request-validation-enrichment`: Generate richer requestBody schema from Laravel FormRequest rules for updated endpoints.
- `laravel-openapi-response-example-enrichment`: Generate richer response/error schema and examples for updated endpoints.

### Modified Capabilities

## Impact

- Affected code:
  - `skills/laravel-api-docs/src/InferCandidates/FormRequestParser.php`
  - `skills/laravel-api-docs/src/OpenApiGenerator/OpenApiGenerator.php`
  - PHP controller / service parser outputs consumed by the generator
- Affected output:
  - `docs/api-docs/openapi.yaml`
  - Apidog imported endpoint details for updated APIs
- Affected docs:
  - `skills/laravel-api-docs/SKILL.md`
