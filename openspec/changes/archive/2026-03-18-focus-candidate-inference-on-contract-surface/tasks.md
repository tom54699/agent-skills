## 1. Candidate inference 規則收斂

- [x] 1.1 盤點目前 `Analyzer` 內哪些 `updated` 訊號屬於 contract/doc surface，哪些屬於 internal-only dependency，整理成可實作的判斷表。
- [x] 1.2 調整 `candidate_subset` 與 `candidate_resolver`，讓 `updated` 僅由 route 以外的 contract/doc surface 訊號成立。
- [x] 1.3 移除或降權純 service / repository / query / 局部變數變更對 `updated` 的直接影響。
- [x] 1.4 保留 `new|deleted` 的既有語意，確認此次收斂只影響 `updated` 邊界。

## 2. 文件訊號與解析能力補強

- [x] 2.1 檢查 `ControllerParser`、`ActionMetadata` 目前已提供哪些 description、response annotation 與例外契約訊號。
- [x] 2.2 補足必要的結構化欄位，讓 description 與可支援的 annotation parameter 變更能成為明確的 candidate signal。
- [x] 2.3 調整 `reason` / `signals` 輸出，清楚區分 request、response、error contract、documentation annotation 與 internal-only 排除原因。

## 3. 文件更新

- [x] 3.1 更新 `skills/.curated/laravel-api-docs/SKILL.md`，說明 candidate inference 已從 dependency-driven 收斂為 contract/doc-surface-driven。
- [x] 3.2 更新 [laravel-api-docs-guided-sync.md](/Users/athena/Documents/workSpace/私人/Agent-Skills/docs/laravel-api-docs-guided-sync.md)，補上哪些變更會觸發文件更新、哪些不會。
- [x] 3.3 視需要補一段未來版本規劃，記錄「skill 版本通知 / 更新提醒」仍是後續議題，避免與本次規則收斂混淆。

## 4. 驗證與回歸

- [x] 4.1 補測試覆蓋 request、response、exception contract 與 description/annotation parameter 變更會命中 `updated`。
- [x] 4.2 補測試覆蓋純 service 內部變數、repository/query 細節變更不會單獨命中 `updated`。
- [x] 4.3 驗證 route 新增與 baseline 驅動的 `deleted` 不受本次收斂影響。
- [x] 4.4 以代表性專案回歸 guided-sync，確認候選數量下降但不漏掉真正需要更新文件的 API。
