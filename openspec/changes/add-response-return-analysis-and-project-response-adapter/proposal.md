## Why

目前 generator 的 response 主要仍是 heuristic-based：

- 成功回應多半只抓 `data`，沒有完整反映實際 response envelope。
- controller 的實際 `return` 形式沒有被系統性分析。
- 專案自訂 wrapper 例如 `apiResponse()` 與 Laravel 通用 `response()->json()` 邏輯混在一起，容易誤把專案慣例寫死成通用規則。

## What Changes

- 新增 Laravel response return analyzer，先解析 controller 實際回傳形式。
- 新增 project response adapter 層，讓像 `apiResponse()` 這類 wrapper 走專案特化處理。
- 讓 success / error response 都能生成完整 envelope，而不是只剩 `data`。

## Capabilities

### New Capabilities
- `laravel-openapi-response-return-analysis`: generated responses can be derived from actual controller return shapes and project adapters.

### Modified Capabilities
- `laravel-openapi-response-example-enrichment`: response examples and schema MUST reflect fuller success/error envelopes.

## Impact

- 影響 `skills/laravel-api-docs/src/InferCandidates/ControllerParser.php`
- 影響 `skills/laravel-api-docs/src/OpenApiGenerator/OpenApiGenerator.php`
- 可能新增 response adapter 類別
- 影響 `skills/laravel-api-docs/SKILL.md`
