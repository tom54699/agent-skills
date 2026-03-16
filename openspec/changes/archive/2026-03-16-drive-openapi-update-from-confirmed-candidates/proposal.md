## Why

目前 `laravel-api-docs` 的 guided-sync 實作在候選推測後就失去主控權：候選清單雖然可供人工審核，但後續 OpenAPI 產出並不以確認後的 API 清單為輸入，而是重新掃整個專案自行決定輸出範圍。這讓「先猜候選 -> 與使用者確認 -> 只更新確認項目」的流程承諾落空。

此外，候選確認階段目前缺少明確的互動契約。使用者需要看到的是精簡 API 清單，而不是一開始就被大量 debug 與分析細節淹沒；同時也需要能反覆刪除、保留、補新增 API，直到最終確認。

## What Changes

- 定義候選確認階段的互動契約：先呈現精簡 API 清單，支援反覆增刪修正，直到使用者確認 final list。
- 定義 final list 為後續 OpenAPI 更新的唯一輸入。
- 保持既有初始化 / 日常分流、候選推測規則、Apidog 同步與 HTML 產生的大方向不變。
- 明確區分 LLM orchestration 與 shell 腳本職責：shell 負責候選推測與文件處理，LLM 負責清單互動與確認。

## Capabilities

### New Capabilities
- `laravel-api-docs-confirmed-candidate-apply`: guided-sync 必須以確認後的最終 API 清單作為 OpenAPI 更新輸入，並支援互動式候選確認迴圈。

### Modified Capabilities
- `laravel-api-docs-guided-sync`: 補強 Step 5/6 的契約，明確要求 final list 驅動後續文件更新。

## Impact

- 影響檔案：
  - `skills/laravel-api-docs/SKILL.md`
  - `skills/laravel-api-docs/scripts/infer-candidates.sh`
  - `skills/laravel-api-docs/scripts/gen-openapi.sh`
  - 可能新增 `skills/laravel-api-docs/scripts/apply-confirmed-candidates.sh`
- 影響流程：
  - 候選清單確認從一次性展示改為可反覆修正的 guided loop。
  - OpenAPI 更新範圍從全專案掃描改為 final list 驅動。
