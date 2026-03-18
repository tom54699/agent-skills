## Context

目前 `OpenApiGenerator` 在建立 operation 時，只有 `isBodyMethod($route->method)` 成立才會去解析 FormRequest 與 inline validation，並將結果生成為 `requestBody`。這個設計對 POST/PUT/PATCH 可行，但對 GET 等非 body 請求會直接跳過 request 規則解析，導致明明存在於 Laravel validation 的 query string 契約無法反映在 OpenAPI `parameters`。

既有 parser 與欄位正規化能力已能產出 request fields，因此這次不需要重做 validation parsing；主要缺口在於 generator 尚未將同一批 request fields 依 HTTP method 映射到不同的 OpenAPI 區塊。

限制條件：
- 必須保留 body method 既有 `requestBody` 行為與輸出格式。
- 優先滿足 GET / 非 body 請求的 query parameters，不擴充到 header / cookie / path parameter 自動推導。
- 避免過度設計複雜 query serialization；先以穩定可產出的 schema/required/example 為主。

## Goals / Non-Goals

**Goals:**
- 讓 GET 與其他 non-body routes 也會解析 FormRequest 與 inline validation。
- 將可映射的 validation 欄位輸出為 OpenAPI `parameters`，預設 `in: query`。
- 保留既有 body method `requestBody` 生成邏輯，不讓 GET 額外出現 `requestBody`。
- 補上對應測試與文件，說明 body/non-body 的 request 輸出規則。

**Non-Goals:**
- 不在本次自動推導 path parameter、header parameter、cookie parameter。
- 不在本次完整處理所有 OpenAPI deepObject / form explode 序列化策略。
- 不變更 candidate inference 邏輯；本次只影響 OpenAPI generation。

## Decisions

### 1. 統一先解析 request fields，再決定輸出位置

- 決策：
  - 不再把 FormRequest / inline validation 的解析包在 `isBodyMethod()` 條件內。
  - 先統一取得 `requestFields`，再依 method 決定：
    - body methods -> `requestBody`
    - non-body methods -> `parameters`

- 原因：
  - 這是最小改動路線，可重用既有 parser、rule normalization、example 生成能力。

- 替代方案：
  - 另寫一套 query-only parser。
  - 缺點是重複邏輯過多，後續規則演進會分叉。

### 2. Non-body request 欄位預設映射為 `in: query`

- 決策：
  - 對 `isBodyMethod()` 為 false 的 route，validation 欄位預設生成為 `parameters[*].in = query`。
  - `required` 來自 validation 規則。
  - `schema` 重用既有 `fieldSchema()` 結果。
  - 若有可穩定產生 example，優先放在 parameter 的 `example`。

- 原因：
  - 目前問題的核心就是 GET query string 遺漏，先解決主需求。

- 替代方案：
  - 依欄位名稱猜測 path/header/cookie。
  - 缺點是猜測風險高，且超出當前需求。

### 3. Query parameter 名稱優先沿用 validation field key

- 決策：
  - query parameter 名稱先沿用 parser 產生的欄位名稱。
  - dotted / wildcard 欄位暫不升級為複雜 serialization 策略，優先保留原始名稱與 schema。

- 原因：
  - 避免一次擴充太多 OpenAPI serialization 細節。
  - 對現有專案來說，先有可讀可見的 query parameters 比完全缺失更重要。

- 替代方案：
  - 同步導入 `style` / `explode` / `deepObject` 推導。
  - 缺點是改動面過大，且專案慣例差異很大。

### 4. Review 與文件說明要同步區分 body/non-body

- 決策：
  - `SKILL.md` 與 guided-sync 文件要明確寫出：
    - body methods 生成 `requestBody`
    - non-body methods 生成 `parameters`
  - 測試需同時鎖住 GET FormRequest、GET inline validation 與 POST 不回歸。

- 原因：
  - 這次變更屬於輸出契約修正，文件與測試若不同步，後續很容易再退化成只支援 body methods。

## Risks / Trade-offs

- [Risk] 某些 GET 驗證欄位其實語意上不是 query，而是 path 或自定義 transport。
  -> Mitigation：本次只承諾 validation source 預設映射為 query，文件中明講限制。

- [Risk] dotted/wildcard 欄位在 query parameter 表達上可能不夠理想。
  -> Mitigation：先保留原始欄位名稱與 schema，後續若有需要再做 serialization 規則優化。

- [Risk] 將 request field 解析抽出後，可能影響既有 requestBody review items 或 examples。
  -> Mitigation：以回歸測試鎖住 body methods 現有輸出，並新增 non-body 專屬測試。

## Migration Plan

1. 抽出 request field 收集流程，讓 body/non-body 共用同一來源。
2. 新增 query parameter 生成函式，將 request fields 映射為 OpenAPI `parameters`。
3. 只在 body methods 產生 `requestBody`，在 non-body methods 產生 `parameters`。
4. 補測試覆蓋 GET FormRequest、GET inline validation、POST requestBody 與 mixed regressions。
5. 更新 `SKILL.md` 與 `docs/laravel-api-docs-guided-sync.md`，說明新的輸出規則。

## Open Questions

- DELETE 這類 non-body methods 是否一律比照 GET 產生 query parameters，或要先只承諾 GET？
- 對 array / nested query params，要不要在第一版就補 `style` / `explode`，還是先輸出基本 schema 即可？
