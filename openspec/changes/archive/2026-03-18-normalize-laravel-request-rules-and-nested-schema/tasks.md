## 1. Rule Normalization

- [x] 1.1 擴充 `skills/.curated/laravel-api-docs/src/InferCandidates/FormRequestParser.php`，補齊高頻 Laravel request rules 的 normalization。
- [x] 1.2 將 Password builder 拆成 capability，而不是視為單一規則字串。
- [x] 1.3 為部分可映射與不可可靠映射的規則保留 unresolved metadata。

## 2. Nested Schema Generation

- [x] 2.1 擴充 `skills/.curated/laravel-api-docs/src/OpenApiGenerator/OpenApiGenerator.php`，將 dotted fields 轉成 nested object schema。
- [x] 2.2 擴充 wildcard fields 支援，將 `items.*.field` 轉成 array items schema。
- [x] 2.3 確保 required / nullable / constraints 在 nested schema 下仍正確落位。

## 3. Documentation

- [x] 3.1 更新 `skills/.curated/laravel-api-docs/SKILL.md`，說明 request rule normalization 與 unresolved rule 行為。

## 4. Verification

- [x] 4.1 驗證代表性 request（含 `profile.name`、`items.*.id`）可生成正確 nested schema。
- [x] 4.2 驗證 `confirmed`、`same`、Password builder 等高頻規則不再漏欄位。
