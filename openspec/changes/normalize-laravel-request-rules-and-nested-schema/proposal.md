## Why

目前 OpenAPI generator 雖然已能解析部分 Laravel FormRequest 規則，但仍有三個明顯缺口：

- 規則支援範圍偏窄，許多高頻 Laravel rule 仍無法穩定映射。
- 巢狀欄位與 wildcard 欄位仍以平面欄位處理，無法生成正確的 nested object / array schema。
- 對無法可靠映射的規則沒有一致的降級策略，導致 schema 容易不完整或過度猜測。

## What Changes

- 擴充 Laravel request rule normalization，補強高頻 validation rule 的支援。
- 將 dotted fields 與 wildcard fields 轉成真正的 nested OpenAPI schema。
- 為部分可映射與不可可靠映射的規則建立降級表示方式，保留 unresolved 訊號供後續 review loop 使用。

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `laravel-openapi-request-validation-enrichment`: requestBody schema MUST reflect more Laravel-native rules and nested field shapes.

## Impact

- 影響 `skills/laravel-api-docs/src/InferCandidates/FormRequestParser.php`
- 影響 `skills/laravel-api-docs/src/OpenApiGenerator/OpenApiGenerator.php`
- 影響 `skills/laravel-api-docs/SKILL.md`
