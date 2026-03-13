## Why

即使 request / response parser 持續補強，仍會遇到無法可靠靜態分析的情況：

- 複雜 validation rules
- 動態 response payload
- 不確定的 security 判斷
- 低信心 example

如果沒有 review loop，系統只能在「硬猜」與「忽略」之間選一個，文件品質不穩定。

## What Changes

- 在 `gen-openapi` 後新增 unresolved analysis review artifact。
- guided-sync 流程在 upload 前插入 review gate，只讓低信心項目進入使用者/LLM 討論。
- review 決策可回填 OpenAPI draft，再繼續上傳與產 HTML。

## Capabilities

### New Capabilities
- `laravel-api-docs-openapi-review-loop`: guided sync can pause on unresolved request/response/security analysis and resume after review decisions.

## Impact

- 影響 `skills/laravel-api-docs/SKILL.md`
- 可能新增 review artifact 產生器與 apply 邏輯
- 影響 guided-sync 流程文件
