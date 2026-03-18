## 1. Generator 邏輯調整

- [x] 1.1 將 `OpenApiGenerator` 的 request field 收集流程從 `isBodyMethod()` 條件中抽出，讓 body 與 non-body routes 共用同一來源。
- [x] 1.2 為 non-body routes 新增 query parameter 生成邏輯，將 FormRequest 與 inline validation 欄位映射到 `parameters`。
- [x] 1.3 保留 body methods 的 `requestBody` 行為，確認 GET / non-body routes 不會誤產生 `requestBody`。
- [x] 1.4 視需要補上 parameter example、required 與 schema keyword 映射，沿用既有 field normalization 結果。

## 2. 測試與回歸

- [x] 2.1 新增 GET + FormRequest 測試，確認生成的 operation 含有 `in: query` 的 `parameters`。
- [x] 2.2 新增 GET + inline validation 測試，確認不使用 FormRequest 時仍可生成 query `parameters`。
- [x] 2.3 新增 POST/PUT/PATCH 回歸測試，確認既有 `requestBody` 行為不受影響。
- [x] 2.4 覆蓋至少一個 required 欄位與一個具型別/限制欄位，確認 query parameter schema 正確。

## 3. 文件更新

- [x] 3.1 更新 `skills/.curated/laravel-api-docs/SKILL.md`，說明 non-body routes 會將 request validation 轉成 query parameters。
- [x] 3.2 更新 [laravel-api-docs-guided-sync.md](/Users/athena/Documents/workSpace/私人/Agent-Skills/docs/laravel-api-docs-guided-sync.md)，補上 body vs non-body 的 request 輸出規則。
- [x] 3.3 補一段限制說明，明確記錄本次只處理 `query parameters`，不自動推導 path/header/cookie parameters。
