## 1. Request Validation Enrichment

- [x] 1.1 擴充 `skills/laravel-api-docs/src/InferCandidates/FormRequestParser.php`，支援更多常見 Laravel validation rule 映射。
- [x] 1.2 擴充 `skills/laravel-api-docs/src/OpenApiGenerator/OpenApiGenerator.php`，將新增的 rule 映射輸出為更完整的 requestBody schema。
- [x] 1.3 為 requestBody 產生 deterministic example，至少覆蓋 scalar、enum、array 欄位。

## 2. Response And Example Enrichment

- [x] 2.1 擴充 `skills/laravel-api-docs/src/OpenApiGenerator/OpenApiGenerator.php`，讓 updated endpoint 的 responses 可吸收 controller / service / exception 錯誤訊號。
- [x] 2.2 產生基本 success response example 與 error response example。
- [x] 2.3 保持在缺少可靠訊號時的保守 fallback，避免捏造過度詳細的 response schema。

## 3. Verification And Documentation

- [x] 3.1 在真實 Laravel 專案驗證代表性 updated endpoints，確認 request 規則與 response example 已反映到 `openapi.yaml`。
- [ ] 3.2 驗證同步到 Apidog 後，requestBody 規則與 examples 在 UI 中可見。
- [x] 3.3 更新 `skills/laravel-api-docs/SKILL.md`，說明 updated endpoint enrich 的目標與目前支援範圍。
