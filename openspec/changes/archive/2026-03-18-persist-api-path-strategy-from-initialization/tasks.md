## 1. 初始化決策與持久化

- [x] 1.1 擴充初始化流程，當無 success history 時要求使用者選擇 API path strategy。
- [x] 1.2 補上建議值邏輯：若存在本地 OpenAPI 或 Apidog baseline，嘗試推導較可能的 path strategy 供使用者確認。
- [x] 1.3 在首次成功同步後，將 `path_strategy` 寫入 success history record。

## 2. 共用 path normalization

- [x] 2.1 抽出 route path normalization 邏輯，支援 `keep-full-path` 與 `strip-api-prefix-to-server`。
- [x] 2.2 讓 `Analyzer` 的 candidate route key 與 `OpenApiGenerator` 的輸出 path 共用同一策略。
- [x] 2.3 對 legacy history 缺少 `path_strategy` 的情況補 fallback 與可辨識提示。

## 3. 文件與觀測資訊

- [x] 3.1 更新 `skills/.curated/laravel-api-docs/SKILL.md`，說明初始化必選 path strategy 與後續沿用規則。
- [x] 3.2 更新 [laravel-api-docs-guided-sync.md](/Users/athena/Documents/workSpace/私人/Agent-Skills/docs/laravel-api-docs-guided-sync.md)，補上 `keep-full-path` 與 `strip-api-prefix-to-server` 對照範例。
- [x] 3.3 擴充 debug/meta，讓使用者能看到當前專案的 `path_strategy`。

## 4. 驗證與回歸

- [x] 4.1 補測試覆蓋兩種 path strategy 下的 route normalization 與 OpenAPI path 輸出。
- [x] 4.2 驗證初始化選定策略後，daily run 會穩定沿用同一策略。
- [x] 4.3 與 `generate-query-parameters-for-non-body-routes` 一起回歸，確認 GET query parameters 與 path strategy 組合後仍保持一致。
