## Context

目前 response 生成邏輯缺少清楚分層：一部分來自 controller parse，一部分來自 path heuristic，導致 schema 與 example 常常不完整。另一方面，不同 Laravel 專案會有不同 response wrapper，因此不能把 `apiResponse()` 當成通用 Laravel 規則。

## Goals / Non-Goals

**Goals**
- 先解析 controller 實際 return response 形式。
- 將 Laravel 通用 response 分析與 project-specific wrapper adapter 分離。
- 讓 success / error response schema 與 example 更完整。

**Non-Goals**
- 不在這筆 change 處理 request nested schema。
- 不在這筆 change 處理 LLM review loop。

## Decisions

### 1. 新增通用 response return analyzer

優先支援：

- `response()->json([...], 200)`
- `new JsonResponse([...], 200)`
- `return [...]`
- `response()->apiResponse(...)`
- `JsonResource::make(...)`
- `Resource::collection(...)`

analyzer 先抽成中介格式，包含：

- status
- return kind
- payload literal / unresolved payload
- adapter hint

### 2. `apiResponse()` 走 project adapter

像 `response()->apiResponse(code, message, data, status)` 這類 wrapper 不寫死在 Laravel 通用邏輯，而由 project adapter 定義：

- envelope 欄位
- code / message / data / status 的參數位置
- error response 是否共用相同 envelope

### 3. success / error response 都使用完整 envelope

當 return analyzer 或 adapter 能可靠解析時：

- success response MUST 包含完整 envelope
- error response MUST 反映專案既有錯誤 envelope

無法可靠解析時才回退 generic schema。

## Risks / Trade-offs

- `JsonResource` 與 `ResourceCollection` 很難完整靜態解析，初期可能只能做保守 schema。
- 專案 adapter 需要清楚邊界，避免再把 project conventions 汙染通用層。

## Migration Plan

1. 先擴充 `ControllerParser` 抽 response return metadata。
2. 再補 response analyzer / adapter 類別。
3. 最後讓 `OpenApiGenerator` 改用 analyzer + adapter 組 response schema/example。
