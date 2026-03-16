## 1. Request Validation Enrichment

- [x] 1.1 將 `skills/laravel-api-docs/src/InferCandidates/FormRequestParser.php` 的 rule 解析能力整理成可重用邏輯，避免 FormRequest 與 inline validation 各做一套。
- [x] 1.2 擴充 `skills/laravel-api-docs/src/InferCandidates/ControllerParser.php`，支援抽取 `$request->validate([...])` / `Validator::make(..., [...])` 的 inline validation rules。
- [x] 1.3 擴充 `skills/laravel-api-docs/src/OpenApiGenerator/OpenApiGenerator.php`，在沒有 FormRequest 時以 inline validation rules 生成 requestBody schema。
- [x] 1.4 為 inline validation 來源的 requestBody 產生 deterministic example，至少覆蓋 scalar、enum、array 欄位。

## 2. Response And Example Enrichment

- [x] 2.1 擴充 `skills/laravel-api-docs/src/OpenApiGenerator/OpenApiGenerator.php`，讓 updated endpoint 的 responses 可吸收 controller / service / exception 錯誤訊號。
- [x] 2.2 產生基本 success response example 與 error response example。
- [x] 2.3 保持在缺少可靠訊號時的保守 fallback，避免捏造過度詳細的 response schema。

## 3. Verification And Documentation

- [x] 3.1 在真實 Laravel 專案驗證代表性 inline validation endpoints（如 `checkEmailExists`、`verifyOTPForBankInfo`），確認 request 規則已反映到 `openapi.yaml`。
- [x] 3.2 以 `myan-ride` 的 confirmed endpoint 回歸，確認原本空 requestBody 的 POST/PUT endpoints 不再輸出空物件 schema。
- [x] 3.3 驗證同步到 Apidog 後，inline validation 來源的 requestBody 規則與 examples 在遠端匯出中可見。
- [x] 3.4 更新 `skills/laravel-api-docs/SKILL.md`，說明 updated endpoint enrich 現在同時涵蓋 FormRequest 與 inline validation。
