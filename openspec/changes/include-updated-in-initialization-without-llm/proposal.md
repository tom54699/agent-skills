## Why

目前初始化流程在無 OpenAPI 基準時採 `new-only`，會漏掉「只改 FormRequest 規則、Service 例外、Exception 回應」但仍需同步給前端的 API 變更。由於此流程不依賴 LLM，應在初始化階段就完整推測 `updated`，避免文件落差。

## What Changes

- 將初始化推測由 `new-only` 改為同時輸出 `new` 與 `updated`（仍不自動輸出 `deleted`）。
- 新增反向關聯推測：若變更檔為 `FormRequest/Service/Exception/Resource`，可回推對應 `Controller@action` 與 endpoint。
- 補強 response 推測規則：支援 `response()->apiResponse(...)`、`BaseException` getter（`getErrorCode/getStatusCode/getData`）與 `Throwable` fallback。
- 在候選輸出中明確標示 `change_reason`、`confidence`、`missing_fields`，讓使用者審核後再寫入 OpenAPI。

## Capabilities

### New Capabilities
- `laravel-api-docs-initialization-updated-inference`: 定義無 LLM 的初始化推測規則，要求在無 baseline 時仍可推測 `updated` 並提供可審核訊號。

### Modified Capabilities
- None.

## Impact

- 影響檔案：
  - `skills/laravel-api-docs/SKILL.md`
  - `skills/laravel-api-docs/scripts/infer-candidates.sh`
  - `skills/laravel-api-docs/scripts/parse-controller.sh`
  - `skills/laravel-api-docs/scripts/parse-form-request.sh`
  - `skills/laravel-api-docs/scripts/parse-service.sh`
- 影響流程：
  - 初始化（無 success history）改為 `new + updated` 推測。
  - 使用者在確認清單時可看到參數/回應變更來源與缺漏欄位，降低誤同步風險。
