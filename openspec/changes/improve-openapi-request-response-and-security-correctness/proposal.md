## Why

目前 OpenAPI generator 在三個地方仍不夠正確：FormRequest 的 array-style / Laravel 密碼規則會漏欄位，`apiResponse()` 的成功 payload 會被 path heuristic 亂猜，且 JWT `security` 幾乎是全域預設，導致不需要 token 的 API 也被標成需驗證。

## What Changes

- 補強 Laravel FormRequest rule 解析，正確處理 array-style rules 與常見密碼/比對規則。
- 成功 response 改成優先根據 `apiResponse()` 真實第三參數生成 example，而不是只靠 path heuristic。
- JWT `security` 改成 route middleware-driven，只在需要驗證的 operation 上標記 `bearerAuth`。

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `laravel-openapi-request-validation-enrichment`: requestBody schema must correctly reflect more Laravel-native validation shapes.
- `laravel-openapi-response-example-enrichment`: success response examples must prefer controller `apiResponse()` payloads over path heuristics.
- `laravel-api-docs-guided-sync`: generated OpenAPI security requirements must align with route middleware instead of global defaults.

## Impact

- 影響 `skills/laravel-api-docs/src/InferCandidates/FormRequestParser.php`
- 影響 `skills/laravel-api-docs/src/InferCandidates/ControllerParser.php`
- 影響 `skills/laravel-api-docs/src/OpenApiGenerator/OpenApiGenerator.php`
- 影響 `skills/laravel-api-docs/src/OpenApiGenerator/RouteDefinition.php`
