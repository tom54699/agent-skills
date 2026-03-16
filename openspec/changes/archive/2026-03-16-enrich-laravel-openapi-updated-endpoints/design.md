## Context

目前 PHP 版 `gen-openapi` 已能穩定生成 candidate-driven OpenAPI，但對 `updated` endpoint 來說，產出內容仍過於簡化：

- requestBody 只反映基本欄位與 `required`
- Laravel FormRequest 規則只映射少數 schema keyword
- responses 多半仍是固定預設模板
- 幾乎沒有 request / response examples

這會讓 `updated` endpoint 即使成功同步到 Apidog，文件品質仍不足以支撐前後端協作、驗證規則理解與測試資料準備。

## Goals / Non-Goals

**Goals:**
- 補強 `updated` endpoint 的 request schema，讓常見 Laravel validation rule 可轉成更完整的 OpenAPI schema。
- 補強 controller inline validation，讓 `Request $request` + `$request->validate([...])` / `Validator::make(...)` 也能生成 requestBody schema。
- 補強成功與錯誤 responses，讓 OpenAPI 能表達更多業務錯誤與錯誤碼來源。
- 為 requestBody 與 responses 產生基本 examples，優先服務 `updated` endpoint。
- 保持目前 PHP generator 架構，不再退回 shell parser。

**Non-Goals:**
- 不追求完整覆蓋所有 Laravel validation rule。
- 不建立完整 AST 或引入大型第三方 parser 套件。
- 不在這一筆 change 內處理 Apidog conflict 規則重分類。

## Decisions

### 1. 先擴充現有 PHP parser，而不是重寫成 AST 分析器

目前 `FormRequestParser` 已能抽取 `rules()` 區塊並解析部分 pipe 規則。這一筆 change 會沿用這種 parser，補強：
- `nullable`
- `string` / `integer` / `numeric` / `boolean` / `array`
- `min` / `max`
- `between`
- `size`
- `digits`
- `email`
- `date`
- `in`

理由：
- 先提升文件品質，不做過度設計
- 現有 parser 已足以處理專案中多數靜態字串規則

替代方案：
- 改用完整 AST 套件解析 FormRequest
  - 放棄，因為成本高，超出目前需求

### 1.1 共用 rule parser，同時支援 FormRequest 與 inline validation

`myan-ride` 的多數空 requestBody endpoint 並不是因為沒有驗證規則，而是規則寫在 controller action 內，例如：

- `$request->validate([...])`
- `Validator::make($payload, [...])`

因此不應再把 request 規則解析能力綁死在 `FormRequestParser::parseRules(file)`。這一筆 change 會把「rules block -> field schema」這層邏輯抽成可重用能力，讓：

- FormRequest 仍可走既有 `rules()` 路徑
- ControllerParser 可額外抽出 inline rules block
- OpenApiGenerator 對兩種來源一視同仁地生成 schema / example

理由：
- 問題核心是來源不同，不是 rule-to-schema 映射本身不足
- 共用 parser 比再做一套 inline parser 更容易維持一致行為

### 2. request example 由 schema 生成預設值，而非要求人工維護

對每個 request field，依 type / enum / format 產生 deterministic example：
- string -> `"string"`
- email -> `"user@example.com"`
- integer -> `1`
- boolean -> `true`
- enum -> 第一個 enum 值
- array -> 至少一個樣本元素

理由：
- 可以快速讓 Apidog 有可用的測試起點
- 不需要在 Laravel 程式碼內新增額外註記

替代方案：
- 完全不產 example，等人工補
  - 放棄，因為目前你已明確感受到文件可用性不足

### 3. response enrich 採「成功回應基本例子 + 錯誤回應來源補強」

成功回應先保持保守：
- 200/201 仍以 `data: object` 為基礎
- 若 controller / service 已有可用訊號，再逐步補欄位與 example

錯誤回應補強重點：
- 從 controller / service / exception parser 收斂錯誤訊息與錯誤碼
- 在 `ErrorResponse` 或 operation-level response 中加入 example

理由：
- 錯誤資訊通常是 updated endpoint 最需要被同步的文件差異
- 相較完整成功 payload 結構推導，錯誤例子更容易先做出實際價值

替代方案：
- 直接嘗試完整推導 Resource / API response payload
  - 放棄，因為目前訊號不足，容易失真

### 4. enrich 先以 `updated` endpoint 優先，保留向 `new` 擴展的能力

本筆 change 以 `updated` endpoint 為優先驗證範圍，但實作不應把 enrich 硬寫死成只能作用於 `updated`。Generator 可沿用相同能力處理 `new`，只是驗收時以 `updated` 為重點。

## Risks / Trade-offs

- [Validation rule 只覆蓋常見子集] → 先明確定義支援範圍，未支援規則保持保守輸出。
- [Example 是推導值，不一定貼近真實業務樣本] → 保證 deterministic 與型別正確，後續再允許人工補值。
- [錯誤 response 來源分散於 controller/service/exception] → 優先整合現有 parser 訊號，不新增過重依賴。
- [更完整 schema 可能讓 conflict compare 更常命中] → 接受這個副作用，因為文件品質優先。

## Migration Plan

1. 先將 `FormRequestParser` 的 rule-to-schema 邏輯整理成可供 inline validation 重用。
2. 擴充 `ControllerParser`，讓它能抽取 controller action 內的 inline validation rules。
3. 再擴充 `OpenApiGenerator`，優先使用 FormRequest，否則回退到 inline validation 規則生成 requestBody。
4. 以代表性的 `updated` endpoints 驗證：
   - request 規則是否可見
   - response example 是否可見
   - 錯誤資訊是否更完整
5. 最後更新 `SKILL.md` 與 OpenSpec tasks。

## Open Questions

- 是否要先定義一份 `field name -> example` 的 heuristics，例如 `phone_number`、`country_code`、`password` 等常見欄位。
- 錯誤碼是否優先放在 operation-level response example，或統一回寫 `components/schemas/ErrorResponse`。
