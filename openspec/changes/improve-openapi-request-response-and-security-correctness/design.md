## Context

目前 generator 已經能產 request/response/example，但仍有幾個明顯缺陷：

- FormRequest 只穩定支援 pipe-string 規則，對 array-style rules 會漏欄位。
- `Password::min()->letters()->numbers()`、`same:password`、`regex` 等常見 Laravel 規則沒有被完整映射。
- 成功 response 主要仍靠 path heuristic，像 `login/register` 會硬猜 `token/user`，即使 controller 的 `apiResponse()` 第三參數其實是 `null`。
- OpenAPI root 目前掛了全域 `security`，導致公開 API 也被標成需 JWT。

## Goals / Non-Goals

**Goals**
- 正確保留 Request 欄位與常見 Laravel validation rule 訊號。
- 成功 response example 優先反映 controller `apiResponse()` 可可靠解析出的 data payload。
- JWT `security` 改為 operation-level，依 route middleware 判斷。

**Non-Goals**
- 不引入 AST 套件。
- 不完整覆蓋所有 Laravel validation / response patterns。
- 不處理 Apidog conflict 或 HTML 問答流程。

## Decisions

### 1. FormRequest 先支援常見 array-style rules

`parseRules()` 除了既有 `'field' => 'required|string'`，新增支援：

- `'field' => ['required', 'string', 'max:20']`
- `Password::min(8)->letters()->numbers()`
- `same:password`
- `regex:/.../`

未能可靠映射成 OpenAPI keyword 的規則，至少保留到欄位 description 或 extension，不直接丟失欄位。

### 2. success example 先解析 `apiResponse()` 的第三參數

對 controller `api_responses` 中 `http_status < 400` 的項目：

- `data_expr = null` -> success example 的 `data` 應為 `null` 或空物件的保守型態，不再硬猜 token/user
- `data_expr` 為簡單 array literal -> 解析成 example.data
- 無法解析 -> 才回退 generic success example

### 3. security 改為 route-level

- `components.securitySchemes` 保留
- 移除 root-level `security`
- 每個 operation 根據 route middleware 判定是否加上 `security`

先以保守規則判斷：
- middleware 含 `auth:`、`auth`、`auth:sanctum`、`auth:api`、`jwt`、`jwt.auth`、`auth.driver`、`auth.user` 類型時視為需要 bearer token
- 其他 route 不加 `security`

## Risks / Trade-offs

- `same:password`、複雜 Password rule 沒有直接的 OpenAPI 標準 keyword。
  - 先保留欄位並以 description/example 補強，不硬映射不存在的標準欄位。
- `apiResponse()` 第三參數若不是簡單 literal，仍可能回退 generic。
  - 接受，先避免錯猜。

## Migration Plan

1. 先補 `FormRequestParser` 對 array-style rule 與常見 Laravel 規則的解析。
2. 再補 `ControllerParser` / `OpenApiGenerator` 的 success payload 解析。
3. 最後把 security 改成 middleware-driven，並做代表性驗證。
