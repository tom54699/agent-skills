## Context

目前 `laravel-api-docs` 的 candidate inference 已經從 baseline-driven 調整為 commit-driven，但候選訊號仍偏向程式依賴視角。實作上除了 route、controller、request、resource 之外，service method 與 exception flow 也會直接參與 `updated` 推斷。這樣的好處是召回率高，但缺點是只要 service 內部流程、局部變數或 repository/query 細節有改動，就可能把與 API 文件無關的 endpoint 拉進候選。

對 guided-sync 來說，候選清單的目的是找出「這次哪些 API 文件需要更新」，不是找出「哪些程式碼依賴有變」。因此設計上應收斂到 API contract surface 與 document surface：

- route 與 endpoint mapping
- request schema
- response schema
- error contract / exception mapping
- 可進入 OpenAPI 的註解內容，例如 description、參數說明

限制條件：
- 保留 `new|updated|deleted` 契約，不重做 downstream confirm / generator / Apidog 流程。
- 優先做規則收斂，不導入大型靜態分析器或新外部依賴。
- 文件與測試必須同步補齊，避免規則只存在腦中或對話紀錄。

## Goals / Non-Goals

**Goals:**
- 將 candidate inference 明確收斂到 contract surface 與 doc surface。
- 讓純內部 service / repository / 變數修改不再單獨構成 `updated` 候選。
- 保留 exception 對外錯誤契約、response shape、註解 description / parameter 說明的推導能力。
- 讓 `reason` / `signals` 更能解釋「為何這支 API 文件需要更新」。
- 補上對應測試與文件，讓後續維護者能理解規則邊界。

**Non-Goals:**
- 不在本次引入新的 candidate status。
- 不在本次重寫 OpenAPI generator 或改變 confirmed candidate 的 apply 契約。
- 不保證可解析所有專案自定義 annotation 語法；僅處理目前 skill 已支援或可穩定擴充的文件訊號。

## Decisions

### 1. Candidate inference 改以 contract/doc signals 為準，而非廣義 dependency 變更

- 決策：
  - `new` 繼續只由 route / endpoint mapping 變更成立。
  - `updated` 僅在以下訊號成立時產出：
    - controller action 本體或註解造成文件表面變更
    - FormRequest / inline validation 造成 request schema 變更
    - Resource / response adapter / return response 造成 response schema 或內容說明變更
    - exception mapping 改變對外 status code、error body、error description
  - 單純 service file 變更不得直接構成 `updated`，除非 analyzer 能從該變更連結到 response / error contract。

- 原因：
  - API 文件關注的是對外契約，不是內部依賴拓樸。
  - 這能明顯減少「程式有改，但文件不用動」的假陽性。

- 替代方案：
  - 保留目前 service / exception action-bound 推導。
  - 缺點是噪音仍高，且容易讓使用者誤以為每次 service 調整都要更新 API 文件。

### 2. 註解內容列為第一級文件訊號

- 決策：
  - controller phpdoc 的 `description` 變更視為 `updated` 訊號。
  - 可映射到 OpenAPI 的註解參數若有結構化支援，視為 `updated` 訊號。
  - 註解只作為文件訊號，不凌駕於 route/request/response/exception 等實際契約訊號之上。

- 原因：
  - 使用者明確指出文件註解本身就是 API 文件的重要來源。
  - description 與參數說明變更即使不改程式行為，也應觸發文件更新。

- 替代方案：
  - 繼續把註解變更視為一般 controller diff。
  - 缺點是語意不清，reason/signals 無法說明是文件註解變更還是邏輯變更。

### 3. 保留 exception contract，弱化 internal-only service 推導

- 決策：
  - 例外類別或 exception mapping 若會改變外部 status code、錯誤訊息、錯誤 payload，仍屬 `updated`。
  - service 變更只有在能證明影響 response/error contract 時才納入；若只是方法體、區域變數或查詢細節變動，預設忽略。

- 原因：
  - 這是你提出意見後最重要的邊界：不是完全不看 service，而是不讓它以「內部實作變更」身分直接升格成文件變更。

- 替代方案：
  - 完全移除 service 與 exception 相關訊號。
  - 缺點是會漏掉實際改變錯誤契約或 response shape 的情境。

### 4. 先以最小改動重用既有 parser / signal 結構，再逐步補結構化訊號

- 決策：
  - 先沿用 `ControllerParser`、`ActionMetadata`、`reason/signals` 的既有骨架。
  - 第一階段優先調整 inclusion rules 與 explainability。
  - 若註解參數目前未結構化，先在設計中明確列為擴充點，再評估是否補 parser。

- 原因：
  - 這樣能先把規則導正，不必一次重寫 parser 或 generator。

- 替代方案：
  - 一次導入完整 annotation parser 與更深的 response contract analyzer。
  - 缺點是改動面過大，不符合目前「先收斂噪音」的需求。

## Risks / Trade-offs

- [Risk] 收斂過頭後，某些藏在 service 內的 response shape 變更可能漏抓。
  -> Mitigation：保留「可證明影響 response/error contract 才納入」的路徑，並補對應測試案例。

- [Risk] 註解參數語法若缺乏一致格式，難以穩定判定。
  -> Mitigation：先只承諾支援目前 skill 可解析或可穩定辨識的註解訊號，未知語法留在 review 或後續擴充。

- [Risk] 使用者可能把「程式有變」等同於「文件要變」，收斂後會覺得召回率下降。
  -> Mitigation：在文件中明確說明 candidate inference 現在追的是 contract/doc surface，不是全量程式變更。

- [Risk] reason/signals 語意調整後，既有 debug 閱讀習慣需要重新對齊。
  -> Mitigation：同步更新 `SKILL.md` 與 guided-sync 文件，並保留關鍵欄位命名的一致性。

## Migration Plan

1. 明確定義 contract surface / doc surface 的納入與排除規則。
2. 調整 `Analyzer` 的 subset 與 resolver 邏輯，移除 internal-only service 變更的直接影響。
3. 擴充 `ControllerParser` / `ActionMetadata`，讓 description 與可支援的 annotation parameter 變更可被解釋。
4. 補測試：
   - route / request / response / exception contract 變更應命中
   - description / annotation parameter 變更應命中
   - 純 service 內部變數或 query 細節修改不得命中
5. 更新 `SKILL.md` 與 `docs/laravel-api-docs-guided-sync.md`，說明新的責任邊界與例子。
6. 若驗證顯示漏抓過多，再回頭調整特定 contract analyzer，而不是重新放寬整體 dependency 規則。

## Open Questions

- 目前專案內常見的註解參數格式有哪些，哪些已經能穩定映射到 OpenAPI？
- `response` 的判定邊界要不要包含所有 `return_responses`，還是只限目前 generator 能消化的結構？
- 對於 service 內組裝 error payload 的專案慣例，是否需要一條保守 fallback 規則，避免完全漏抓？
