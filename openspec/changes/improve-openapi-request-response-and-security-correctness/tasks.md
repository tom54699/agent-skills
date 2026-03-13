## 1. Request Parsing

- [x] 1.1 擴充 `skills/laravel-api-docs/src/InferCandidates/FormRequestParser.php`，支援 array-style rules，並保留目前會漏掉的欄位。
- [x] 1.2 補 `regex`、`same`、`Password::min()->letters()->numbers()` 等常見 Laravel 規則的解析與映射。

## 2. Success Response Parsing

- [x] 2.1 擴充 `skills/laravel-api-docs/src/InferCandidates/ControllerParser.php`，讓 `apiResponse()` 成功 payload 可抽出 data expression。
- [x] 2.2 擴充 `skills/laravel-api-docs/src/OpenApiGenerator/OpenApiGenerator.php`，優先用 `apiResponse()` 成功 payload 生成 example，避免 path heuristic 誤判。

## 3. Security Correctness

- [x] 3.1 擴充 route model，保留 middleware 資訊。
- [x] 3.2 調整 `OpenApiGenerator`，移除全域 security，改為 operation-level middleware-driven security。

## 4. Verification

- [x] 4.1 驗證 `/user/register` requestBody 已包含 `password`、`password_confirmation` 與對應 example。
- [x] 4.2 驗證 `apiResponse(..., null, 200)` 不再生成錯誤的 success example。
- [x] 4.3 驗證公開 API 不再自動帶 bearerAuth，而受保護 API 仍保留 security。
