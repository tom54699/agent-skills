## 1. Return Analysis

- [x] 1.1 擴充 `skills/.curated/laravel-api-docs/src/InferCandidates/ControllerParser.php`，抽出 controller 實際 return response metadata。
- [x] 1.2 新增通用 response return analyzer，支援常見 Laravel JSON / Resource return 形式。

## 2. Project Adapter

- [x] 2.1 新增 project response adapter 抽象與 `apiResponse()` adapter。
- [x] 2.2 將專案 envelope 欄位映射與 Laravel 通用 response 分析解耦。

## 3. Response Generation

- [x] 3.1 調整 `skills/.curated/laravel-api-docs/src/OpenApiGenerator/OpenApiGenerator.php`，success response 改用完整 envelope。
- [x] 3.2 調整 error response 生成，優先反映 analyzer / adapter 提供的 envelope 與 example。
- [x] 3.3 保留無法可靠解析時的 generic fallback。

## 4. Documentation

- [x] 4.1 更新 `skills/.curated/laravel-api-docs/SKILL.md`，說明 response analyzer 與 project adapter 分層。

## 5. Verification

- [x] 5.1 驗證 `response()->apiResponse(...)` 可生成完整 `code/message/data` envelope。
- [x] 5.2 驗證 `response()->json([...], 200)` 與 array literal return 可產生合理 schema / example。
