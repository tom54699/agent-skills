## 1. 訊號模型收斂

- [x] 1.1 定義 candidate inference 的強訊號與弱訊號清單，並映射到現有 `signals` 欄位。
- [x] 1.2 調整 `candidate_subset` 與 `candidate_resolver`，讓 controller/service method body diff 不再單獨構成 `updated`。
- [x] 1.3 收緊 service error-contract 推導，避免僅因 exception metadata 存在就判定為 contract change。

## 2. 文件註解訊號補強

- [x] 2.1 擴充 function 文件註解解析，明確支援 description 與可映射到 OpenAPI 的 annotation 類型。
- [x] 2.2 讓 function 文件註解變更成為強訊號，並在 `reason` / `signals` 中清楚標示。

## 3. 文件更新

- [x] 3.1 更新 `skills/.curated/laravel-api-docs/SKILL.md`，說明強訊號 / 弱訊號模型與 function 文件註解角色。
- [x] 3.2 更新 [laravel-api-docs-guided-sync.md](/Users/athena/Documents/workSpace/私人/Agent-Skills/docs/laravel-api-docs-guided-sync.md)，補上哪些 controller/service 變更不再單獨命中候選。

## 4. 驗證與回歸

- [x] 4.1 補測試覆蓋 function 文件註解變更會命中 `updated`。
- [x] 4.2 補測試覆蓋純 enum refactor / 純 controller 或 service body diff 不會單獨命中 `updated`。
- [x] 4.3 以 `myan-ride` 的 `ff619fdd97103cc22752813b2ec902b56aa1cacf` 回歸，確認候選數量明顯下降且保留真正需要更新文件的 API。
